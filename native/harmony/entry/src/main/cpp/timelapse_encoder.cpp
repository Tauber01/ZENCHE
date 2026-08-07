#include "napi/native_api.h"
#include "multimedia/player_framework/native_avcodec_videoencoder.h"
#include "multimedia/player_framework/native_avcodec_base.h"
#include "multimedia/player_framework/native_avformat.h"
#include "multimedia/player_framework/native_avbuffer.h"
#include "multimedia/player_framework/native_avbuffer_info.h"
#include "multimedia/player_framework/native_avmuxer.h"

#include <condition_variable>
#include <cstring>
#include <fcntl.h>
#include <mutex>
#include <queue>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

/** E6 延时合成 native 编码会话（buffer 模式异步回调）。 */
struct TimelapseSession {
  OH_AVCodec *codec = nullptr;
  OH_AVMuxer *muxer = nullptr;
  int32_t trackIndex = -1;
  int outputFd = -1;
  int64_t framesWritten = 0;
  bool muxerStarted = false;
  bool streamChanged = false;
  bool eosSeen = false;
  bool failed = false;

  std::mutex mutex;
  std::condition_variable inputCv;   // 输入槽回调信号
  std::condition_variable streamCv;  // 输出格式变化信号
  std::condition_variable eosCv;     // EOS 输出信号
  std::queue<uint32_t> inputIndexes; // 空闲输入槽 index（buffer 模式回调派发）
  std::queue<OH_AVBuffer *> inputBuffers;
};

std::vector<TimelapseSession *> g_sessions;
std::mutex g_sessionsMutex;

TimelapseSession *findSession(int64_t handle) {
  std::lock_guard<std::mutex> lock(g_sessionsMutex);
  for (TimelapseSession *session : g_sessions) {
    if (reinterpret_cast<int64_t>(session) == handle) {
      return session;
    }
  }
  return nullptr;
}

void removeSession(int64_t handle) {
  std::lock_guard<std::mutex> lock(g_sessionsMutex);
  for (size_t i = 0; i < g_sessions.size(); ++i) {
    if (reinterpret_cast<int64_t>(g_sessions[i]) == handle) {
      g_sessions.erase(g_sessions.begin() + static_cast<long>(i));
      return;
    }
  }
}

void OnEncoderError(OH_AVCodec *codec, int32_t errorCode, void *userData) {
  TimelapseSession *session = static_cast<TimelapseSession *>(userData);
  std::lock_guard<std::mutex> lock(session->mutex);
  session->failed = true;
  session->inputCv.notify_all();
  session->streamCv.notify_all();
  session->eosCv.notify_all();
}

void OnStreamChanged(OH_AVCodec *codec, OH_AVFormat *format, void *userData) {
  TimelapseSession *session = static_cast<TimelapseSession *>(userData);
  int32_t trackIndex = -1;
  if (OH_AVMuxer_AddTrack(session->muxer, &trackIndex, format) != AV_ERR_OK) {
    std::lock_guard<std::mutex> lock(session->mutex);
    session->failed = true;
    session->streamCv.notify_all();
    return;
  }
  session->trackIndex = trackIndex;
  if (OH_AVMuxer_Start(session->muxer) != AV_ERR_OK) {
    std::lock_guard<std::mutex> lock(session->mutex);
    session->failed = true;
    session->streamCv.notify_all();
    return;
  }
  std::lock_guard<std::mutex> lock(session->mutex);
  session->muxerStarted = true;
  session->streamChanged = true;
  session->streamCv.notify_all();
}

void OnNeedInputBuffer(OH_AVCodec *codec, uint32_t index, OH_AVBuffer *buffer,
                       void *userData) {
  TimelapseSession *session = static_cast<TimelapseSession *>(userData);
  std::lock_guard<std::mutex> lock(session->mutex);
  session->inputIndexes.push(index);
  session->inputBuffers.push(buffer);
  session->inputCv.notify_all();
}

void OnNewOutputBuffer(OH_AVCodec *codec, uint32_t index, OH_AVBuffer *buffer,
                       void *userData) {
  TimelapseSession *session = static_cast<TimelapseSession *>(userData);
  OH_AVCodecBufferAttr attr = {};
  OH_AVBuffer_GetBufferAttr(buffer, &attr);
  if ((attr.flags & AVCODEC_BUFFER_FLAGS_EOS) != 0) {
    OH_VideoEncoder_FreeOutputBuffer(codec, index);
    {
      std::lock_guard<std::mutex> lock(session->mutex);
      session->eosSeen = true;
    }
    session->eosCv.notify_all();
    return;
  }
  if (session->muxerStarted) {
    OH_AVMuxer_WriteSampleBuffer(session->muxer,
                                 static_cast<uint32_t>(session->trackIndex),
                                 buffer);
    session->framesWritten++;
  }
  OH_VideoEncoder_FreeOutputBuffer(codec, index);
}

/** createEncoder(width, height, fps, bitRate, outputPath) → handle。 */
napi_value CreateEncoder(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  int32_t width = 0;
  int32_t height = 0;
  int32_t fps = 0;
  int64_t bitRate = 0;
  napi_get_value_int32(env, args[0], &width);
  napi_get_value_int32(env, args[1], &height);
  napi_get_value_int32(env, args[2], &fps);
  napi_get_value_int64(env, args[3], &bitRate);

  size_t pathLen = 0;
  napi_get_value_string_utf8(env, args[4], nullptr, 0, &pathLen);
  std::string outputPath(pathLen, '\0');
  napi_get_value_string_utf8(env, args[4], outputPath.data(), pathLen + 1,
                             &pathLen);

  TimelapseSession *session = new TimelapseSession();

  OH_AVCodecCallback callback = {};
  callback.onError = OnEncoderError;
  callback.onStreamChanged = OnStreamChanged;
  callback.onNeedInputBuffer = OnNeedInputBuffer;
  callback.onNewOutputBuffer = OnNewOutputBuffer;

  session->codec = OH_VideoEncoder_CreateByMime(OH_AVCODEC_MIMETYPE_VIDEO_AVC);
  if (session->codec == nullptr) {
    delete session;
    napi_value fail = nullptr;
    napi_create_int64(env, -1, &fail);
    return fail;
  }
  OH_VideoEncoder_RegisterCallback(session->codec, callback, session);

  OH_AVFormat *format = OH_AVFormat_CreateVideoFormat(
      OH_AVCODEC_MIMETYPE_VIDEO_AVC, width, height);
  OH_AVFormat_SetIntValue(format, OH_MD_KEY_PIXEL_FORMAT, AV_PIXEL_FORMAT_NV12);
  OH_AVFormat_SetLongValue(format, OH_MD_KEY_BITRATE, bitRate);
  OH_AVFormat_SetIntValue(format, OH_MD_KEY_FRAME_RATE, fps);
  OH_AVFormat_SetIntValue(format, OH_MD_KEY_I_FRAME_INTERVAL, 1);
  OH_AVFormat_SetIntValue(format, OH_MD_KEY_PROFILE, AVC_PROFILE_MAIN);
  OH_AVFormat_SetIntValue(format, OH_MD_KEY_RANGE_FLAG, 0);

  if (OH_VideoEncoder_Configure(session->codec, format) != AV_ERR_OK ||
      OH_VideoEncoder_Prepare(session->codec) != AV_ERR_OK) {
    OH_VideoEncoder_Destroy(session->codec);
    OH_AVFormat_Destroy(format);
    delete session;
    napi_value fail = nullptr;
    napi_create_int64(env, -2, &fail);
    return fail;
  }
  OH_AVFormat_Destroy(format);

  session->outputFd = open(outputPath.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
  if (session->outputFd < 0) {
    OH_VideoEncoder_Destroy(session->codec);
    delete session;
    napi_value fail = nullptr;
    napi_create_int64(env, -3, &fail);
    return fail;
  }
  session->muxer =
      OH_AVMuxer_Create(session->outputFd, AV_OUTPUT_FORMAT_MPEG_4);
  if (session->muxer == nullptr) {
    close(session->outputFd);
    OH_VideoEncoder_Destroy(session->codec);
    delete session;
    napi_value fail = nullptr;
    napi_create_int64(env, -4, &fail);
    return fail;
  }

  if (OH_VideoEncoder_Start(session->codec) != AV_ERR_OK) {
    OH_AVMuxer_Destroy(session->muxer);
    close(session->outputFd);
    OH_VideoEncoder_Destroy(session->codec);
    delete session;
    napi_value fail = nullptr;
    napi_create_int64(env, -5, &fail);
    return fail;
  }

  // 等待输出格式变化回调完成 muxer AddTrack+Start（限时 5s）。
  {
    std::unique_lock<std::mutex> lock(session->mutex);
    session->streamCv.wait_for(lock, std::chrono::seconds(5),
                               [session]() {
                                 return session->streamChanged ||
                                        session->failed;
                               });
    if (!session->streamChanged || session->failed) {
      lock.unlock();
      OH_AVMuxer_Destroy(session->muxer);
      close(session->outputFd);
      OH_VideoEncoder_Stop(session->codec);
      OH_VideoEncoder_Destroy(session->codec);
      delete session;
      napi_value fail = nullptr;
      napi_create_int64(env, -6, &fail);
      return fail;
    }
  }

  {
    std::lock_guard<std::mutex> lock(g_sessionsMutex);
    g_sessions.push_back(session);
  }
  napi_value handle = nullptr;
  napi_create_int64(env, reinterpret_cast<int64_t>(session), &handle);
  return handle;
}

/** feedFrame(handle, nv12Bytes, ptsUs) → 0 成功 / 负错误。 */
napi_value FeedFrame(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  int64_t handle = 0;
  napi_get_value_int64(env, args[0], &handle);
  TimelapseSession *session = findSession(handle);
  if (session == nullptr) {
    napi_value fail = nullptr;
    napi_create_int32(env, -1, &fail);
    return fail;
  }

  bool isTypedArray = false;
  napi_is_typedarray(env, args[1], &isTypedArray);
  if (!isTypedArray) {
    napi_value fail = nullptr;
    napi_create_int32(env, -2, &fail);
    return fail;
  }
  void *data = nullptr;
  size_t byteLength = 0;
  napi_typedarray_type type;
  napi_value arraybuffer;
  size_t offset = 0;
  napi_get_typedarray_info(env, args[1], &type, &byteLength, &data,
                           &arraybuffer, &offset);

  int64_t ptsUs = 0;
  napi_get_value_int64(env, args[2], &ptsUs);

  uint32_t inputIndex = 0;
  OH_AVBuffer *inputBuffer = nullptr;
  {
    std::unique_lock<std::mutex> lock(session->mutex);
    // 限时等待输入槽：编码器异常不回调时避免 UI 线程永久阻塞（5s 超时）。
    session->inputCv.wait_for(lock, std::chrono::seconds(5), [session]() {
      return !session->inputIndexes.empty() || session->failed;
    });
    if (session->failed) {
      napi_value fail = nullptr;
      napi_create_int32(env, -3, &fail);
      return fail;
    }
    if (session->inputIndexes.empty()) {
      napi_value fail = nullptr;
      napi_create_int32(env, -4, &fail);
      return fail;
    }
    inputIndex = session->inputIndexes.front();
    inputBuffer = session->inputBuffers.front();
    session->inputIndexes.pop();
    session->inputBuffers.pop();
  }

  uint8_t *addr = OH_AVBuffer_GetAddr(inputBuffer);
  int32_t capacity = OH_AVBuffer_GetCapacity(inputBuffer);
  size_t copySize = byteLength < static_cast<size_t>(capacity)
                        ? byteLength
                        : static_cast<size_t>(capacity);
  if (data != nullptr && copySize > 0) {
    std::memcpy(addr, data, copySize);
  }
  OH_AVCodecBufferAttr attr = {};
  attr.pts = ptsUs;
  attr.size = static_cast<int32_t>(copySize);
  attr.offset = 0;
  attr.flags = 0;
  OH_AVBuffer_SetBufferAttr(inputBuffer, &attr);
  OH_VideoEncoder_PushInputBuffer(session->codec, inputIndex);

  napi_value ok = nullptr;
  napi_create_int32(env, 0, &ok);
  return ok;
}

/** finishEncoder(handle) → 写帧数；失败返回负错误。 */
napi_value FinishEncoder(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  int64_t handle = 0;
  napi_get_value_int64(env, args[0], &handle);
  TimelapseSession *session = findSession(handle);
  if (session == nullptr) {
    napi_value fail = nullptr;
    napi_create_int64(env, -1, &fail);
    return fail;
  }

  OH_VideoEncoder_NotifyEndOfStream(session->codec);
  {
    std::unique_lock<std::mutex> lock(session->mutex);
    session->eosCv.wait_for(lock, std::chrono::seconds(10),
                            [session]() { return session->eosSeen; });
  }

  int64_t framesWritten = session->framesWritten;

  if (session->muxerStarted) {
    OH_AVMuxer_Stop(session->muxer);
  }
  OH_AVMuxer_Destroy(session->muxer);
  session->muxer = nullptr;
  close(session->outputFd);
  session->outputFd = -1;
  OH_VideoEncoder_Stop(session->codec);
  OH_VideoEncoder_Destroy(session->codec);
  session->codec = nullptr;

  removeSession(handle);
  delete session;

  napi_value result = nullptr;
  napi_create_int64(env, framesWritten, &result);
  return result;
}

/** destroyEncoder(handle) —— 取消路径清理，不等待 EOS。 */
napi_value DestroyEncoder(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  int64_t handle = 0;
  napi_get_value_int64(env, args[0], &handle);
  TimelapseSession *session = findSession(handle);
  if (session == nullptr) {
    napi_value ok = nullptr;
    napi_get_undefined(env, &ok);
    return ok;
  }

  if (session->muxerStarted) {
    OH_AVMuxer_Stop(session->muxer);
  }
  if (session->muxer != nullptr) {
    OH_AVMuxer_Destroy(session->muxer);
  }
  if (session->outputFd >= 0) {
    close(session->outputFd);
  }
  if (session->codec != nullptr) {
    OH_VideoEncoder_Stop(session->codec);
    OH_VideoEncoder_Destroy(session->codec);
  }

  removeSession(handle);
  delete session;

  napi_value ok = nullptr;
  napi_get_undefined(env, &ok);
  return ok;
}

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor descriptors[] = {
      {"createEncoder", nullptr, CreateEncoder, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"feedFrame", nullptr, FeedFrame, nullptr, nullptr, nullptr, napi_default,
       nullptr},
      {"finishEncoder", nullptr, FinishEncoder, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"destroyEncoder", nullptr, DestroyEncoder, nullptr, nullptr, nullptr,
       napi_default, nullptr},
  };
  napi_define_properties(env, exports,
                         sizeof(descriptors) / sizeof(descriptors[0]),
                         descriptors);
  return exports;
}

}  // namespace

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "timelapse",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterTimelapseModule(void) {
  napi_module_register(&g_module);
}

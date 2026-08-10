import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const source = await readFile(new URL(
  'native/android/app/src/main/java/com/tauber/nikonlink/LocalCameraController.java',
  root,
), 'utf8');

test('Android local camera derives every JPEG stream size from StreamConfigurationMap', () => {
  assert.match(source, /SCALER_STREAM_CONFIGURATION_MAP/);
  assert.match(source, /getOutputSizes\(ImageFormat\.JPEG\)/);
  assert.match(source, /buildStreamCandidates\(jpegSizes\)/);
  assert.match(source, /Math\.max\(size\.getWidth\(\), size\.getHeight\(\)\) <= maxLongEdge/);
  assert.match(source, /Math\.min\(size\.getWidth\(\), size\.getHeight\(\)\) <= maxShortEdge/);
  assert.doesNotMatch(source, /new Size\s*\(/);
});

test('Android local camera retries simpler stream plans after a rejected session', () => {
  assert.match(
    source,
    /for \(StreamCandidate candidate : buildStreamCandidates\(jpegSizes\)\)[\s\S]*openCamera\(cameraId\)[\s\S]*configureSession\(openedCamera, candidate\)[\s\S]*closeAttempt\(openedCamera\)/,
  );
  assert.match(source, /addStreamCandidate\(candidates, preferredPreview, preferredCapture, false\)/);
  assert.match(source, /addStreamCandidate\(candidates, reducedPreview, reducedCapture, false\)/);
  assert.match(source, /addStreamCandidate\(candidates, preferredPreview, preferredPreview, true\)/);
  assert.match(source, /addStreamCandidate\(candidates, reducedPreview, reducedPreview, true\)/);
  assert.match(source, /addStreamCandidate\(candidates, smallest, smallest, true\)/);
  assert.match(source, /openedCamera\.abandoned\.set\(true\)/);
  assert.match(source, /if \(openedCamera\.abandoned\.get\(\)\) camera\.close\(\)/);
});

test('Android local camera falls back from two JPEG outputs to one shared JPEG output', () => {
  assert.match(
    source,
    /ImageReader candidateCapture = candidate\.sharedReader\s*\? candidatePreview\s*:\s*ImageReader\.newInstance/,
  );
  assert.match(
    source,
    /List<Surface> surfaces = candidate\.sharedReader\s*\? Arrays\.asList\(candidatePreview\.getSurface\(\)\)\s*:\s*Arrays\.asList\(candidatePreview\.getSurface\(\), candidateCapture\.getSurface\(\)\)/,
  );
  assert.match(source, /candidatePreview\.setOnImageAvailableListener\(this::onSharedImage/);
  assert.match(source, /activeCaptureReader != activePreviewReader/);
});

test('shared JPEG mode separates still capture frames from preview frames by sensor timestamp', () => {
  assert.match(source, /if \(sharedReader\)[\s\S]*stopRepeating\(\)[\s\S]*drainImages\(activeReader\)/);
  assert.match(source, /onCaptureStarted\([\s\S]*pendingCaptureTimestampNanos = timestamp/);
  assert.match(
    source,
    /captureTimestamp != Long\.MAX_VALUE\s*&& image\.getTimestamp\(\) >= captureTimestamp/,
  );
  assert.match(source, /future\.complete\(jpeg\)/);
  assert.match(source, /setRepeatingRequest\(previewRequest, null, cameraHandler\)/);
  assert.match(
    source,
    /pendingCaptureTimestampNanos = Long\.MAX_VALUE;\s*}\s*try \{\s*CaptureRequest\.Builder builder[\s\S]*activeSession\.capture[\s\S]*return future\.get\(12, TimeUnit\.SECONDS\);\s*} finally \{/,
  );
});

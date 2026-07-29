import { BusinessError } from '@kit.BasicServicesKit';
import { socket } from '@kit.NetworkKit';
import {
  IncomingPhotoFile,
  PhotoLibrary
} from '../storage/PhotoLibrary';

const MAXIMUM_FILE_SIZE: number = 16 * 1024 * 1024 * 1024;
const MAXIMUM_HEADER_SIZE: number = 32 * 1024;
const BASIC_AUTHORIZATION: string =
  'Basic bmlrb25saW5rOm5pa29ubGluaw==';

export const HTTP_PORT: number = 8080;
export type HttpStatusCallback = (status: string) => void;
export type HttpFileCallback = (path: string) => void;

class HttpRequest {
  method: string;
  target: string;
  headers: Map<string, string>;

  constructor(
    method: string,
    target: string,
    headers: Map<string, string>
  ) {
    this.method = method;
    this.target = target;
    this.headers = headers;
  }
}

export class WirelessHttpServer {
  private library: PhotoLibrary;
  private statusCallback: HttpStatusCallback;
  private fileCallback: HttpFileCallback;
  private server?: socket.TCPSocketServer;
  private clients: Array<socket.TCPSocketConnection> = [];
  private running: boolean = false;

  constructor(
    library: PhotoLibrary,
    statusCallback: HttpStatusCallback,
    fileCallback: HttpFileCallback
  ) {
    this.library = library;
    this.statusCallback = statusCallback;
    this.fileCallback = fileCallback;
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    const server: socket.TCPSocketServer =
      socket.constructTCPSocketServerInstance();
    server.on(
      'connect',
      (connection: socket.TCPSocketConnection): void => {
        this.clients.push(connection);
        this.handleClient(connection);
      }
    );
    server.on('error', (error: BusinessError): void => {
      if (this.running) {
        this.statusCallback(`HTTP / WebDAV 接收失败：${error.message}`);
      }
    });
    await server.listen({
      address: '0.0.0.0',
      port: HTTP_PORT,
      family: 1
    });
    this.server = server;
    this.running = true;
  }

  async stop(): Promise<void> {
    this.running = false;
    for (const client of this.clients) {
      try {
        await client.close();
      } catch (error) {
      }
    }
    this.clients = [];
    if (this.server !== undefined) {
      try {
        await this.server.close();
      } catch (error) {
      }
      this.server = undefined;
    }
  }

  private handleClient(client: socket.TCPSocketConnection): void {
    let pending: Uint8Array = new Uint8Array();
    let request: HttpRequest | undefined;
    let incoming: IncomingPhotoFile | undefined;
    let contentLength: number = 0;
    let received: number = 0;
    let settled: boolean = false;

    const removeClient = (): void => {
      const index: number = this.clients.indexOf(client);
      if (index >= 0) {
        this.clients.splice(index, 1);
      }
    };

    const closeClient = async (): Promise<void> => {
      try {
        await client.close();
      } catch (error) {
      }
    };

    const respond = async (
      status: number,
      reason: string,
      body: string = '',
      extraHeaders: string = ''
    ): Promise<void> => {
      const length: number = encodeUtf8(body).length;
      await client.send({
        data: `HTTP/1.1 ${status} ${reason}\r\n` +
          'Connection: close\r\n' +
          `Content-Length: ${length}\r\n` +
          extraHeaders +
          '\r\n' +
          body,
        encoding: 'UTF-8'
      });
      await closeClient();
    };

    const abort = (
      status: number,
      reason: string,
      message: string
    ): void => {
      if (settled) {
        return;
      }
      settled = true;
      if (incoming !== undefined) {
        incoming.abort();
        incoming = undefined;
      }
      respond(status, reason, message);
    };

    const appendBody = (bytes: Uint8Array): void => {
      if (settled || incoming === undefined || bytes.length === 0) {
        return;
      }
      const remaining: number = contentLength - received;
      const count: number = Math.min(bytes.length, remaining);
      try {
        incoming.append(bytes.slice(0, count));
        received += count;
      } catch (error) {
        abort(500, 'Internal Server Error', '无线图片保存失败。');
        return;
      }
      if (received === contentLength) {
        try {
          const path: string = incoming.commit();
          incoming = undefined;
          settled = true;
          respond(
            201,
            'Created',
            `{"saved":"${jsonEscape(lastPathComponent(path))}"}`,
            'Content-Type: application/json; charset=utf-8\r\n'
          );
          this.fileCallback(path);
        } catch (error) {
          abort(500, 'Internal Server Error', '无线图片保存失败。');
        }
      }
    };

    const beginRequest = (value: HttpRequest): boolean => {
      request = value;
      if (value.headers.get('authorization') !== BASIC_AUTHORIZATION) {
        settled = true;
        respond(
          401,
          'Unauthorized',
          '需要使用 Nikon Link 无线收件箱账号。',
          'WWW-Authenticate: Basic realm="Nikon Link"\r\n'
        );
        return false;
      }
      switch (value.method) {
        case 'OPTIONS':
          settled = true;
          respond(
            200,
            'OK',
            '',
            'Allow: OPTIONS, GET, PUT, POST, MKCOL, PROPFIND\r\nDAV: 1\r\n'
          );
          return false;
        case 'GET':
          settled = true;
          respond(
            200,
            'OK',
            '{"service":"Nikon Link","upload":"ready"}',
            'Content-Type: application/json; charset=utf-8\r\n'
          );
          return false;
        case 'MKCOL':
          settled = true;
          respond(201, 'Created', '', 'DAV: 1\r\n');
          return false;
        case 'PROPFIND':
          settled = true;
          respond(
            207,
            'Multi-Status',
            '<?xml version="1.0" encoding="utf-8"?>' +
              '<d:multistatus xmlns:d="DAV:"><d:response><d:href>/</d:href>' +
              '<d:propstat><d:prop><d:resourcetype><d:collection/>' +
              '</d:resourcetype><d:displayname>Nikon Link</d:displayname>' +
              '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>' +
              '</d:response></d:multistatus>',
            'Content-Type: application/xml; charset=utf-8\r\nDAV: 1\r\n'
          );
          return false;
        case 'PUT':
        case 'POST':
          break;
        default:
          settled = true;
          respond(
            405,
            'Method Not Allowed',
            '此无线入口仅支持图片上传。',
            'Allow: OPTIONS, GET, PUT, POST, MKCOL, PROPFIND\r\n'
          );
          return false;
      }

      const lengthText: string | undefined =
        value.headers.get('content-length');
      if (lengthText === undefined) {
        abort(411, 'Length Required', '请提供 Content-Length。');
        return false;
      }
      contentLength = Number(lengthText);
      if (
        !Number.isSafeInteger(contentLength) ||
        contentLength <= 0 ||
        contentLength > MAXIMUM_FILE_SIZE
      ) {
        abort(
          413,
          'Content Too Large',
          '图片大小必须在 1 字节到 16 GB 之间。'
        );
        return false;
      }
      const filename: string | undefined = requestedFilename(value);
      if (filename === undefined || filename.length === 0) {
        abort(
          400,
          'Bad Request',
          '请使用 /upload/文件名，或提供 X-Filename 请求头。'
        );
        return false;
      }
      incoming = this.library.beginReceive(filename);
      this.statusCallback(`正在通过 HTTP / WebDAV 接收 ${filename}`);
      return true;
    };

    client.on('message', (info: socket.SocketMessageInfo): void => {
      if (settled) {
        return;
      }
      const chunk: Uint8Array = new Uint8Array(info.message);
      if (request !== undefined) {
        appendBody(chunk);
        return;
      }
      pending = concatenate(pending, chunk);
      const headerEnd: number = findHeaderEnd(pending);
      if (headerEnd < 0) {
        if (pending.length > MAXIMUM_HEADER_SIZE) {
          abort(431, 'Request Header Fields Too Large', 'HTTP 请求头过大。');
        }
        return;
      }
      if (headerEnd > MAXIMUM_HEADER_SIZE) {
        abort(431, 'Request Header Fields Too Large', 'HTTP 请求头过大。');
        return;
      }
      const parsed: HttpRequest | undefined =
        parseRequest(pending.slice(0, headerEnd));
      if (parsed === undefined) {
        abort(400, 'Bad Request', 'HTTP 请求无效。');
        return;
      }
      const acceptsBody: boolean = beginRequest(parsed);
      if (acceptsBody) {
        appendBody(pending.slice(headerEnd + 4));
      }
      pending = new Uint8Array();
    });
    client.on('error', (error: BusinessError): void => {
      if (!settled) {
        abort(500, 'Internal Server Error', error.message);
      }
    });
    client.on('close', (): void => {
      removeClient();
      if (!settled && incoming !== undefined) {
        incoming.abort();
      }
    });
  }
}

function parseRequest(bytes: Uint8Array): HttpRequest | undefined {
  const lines: Array<string> = decodeUtf8(bytes).split('\r\n');
  if (lines.length === 0) {
    return undefined;
  }
  const first: Array<string> = lines[0].split(' ');
  if (first.length < 2) {
    return undefined;
  }
  const headers: Map<string, string> = new Map<string, string>();
  for (let index: number = 1; index < lines.length; index++) {
    const separator: number = lines[index].indexOf(':');
    if (separator <= 0) {
      continue;
    }
    headers.set(
      lines[index].substring(0, separator).trim().toLowerCase(),
      lines[index].substring(separator + 1).trim()
    );
  }
  return new HttpRequest(first[0].toUpperCase(), first[1], headers);
}

function requestedFilename(request: HttpRequest): string | undefined {
  const explicit: string | undefined = request.headers.get('x-filename');
  if (explicit !== undefined && explicit.trim().length > 0) {
    return explicit.trim();
  }
  const queryIndex: number = request.target.indexOf('?');
  const rawPath: string = queryIndex < 0
    ? request.target
    : request.target.substring(0, queryIndex);
  let path: string = rawPath;
  try {
    path = decodeURIComponent(rawPath);
  } catch (error) {
  }
  if (path !== '/' && path !== '/upload' && path !== '/upload/') {
    return path.substring(path.lastIndexOf('/') + 1);
  }
  if (queryIndex >= 0) {
    const query: string = request.target.substring(queryIndex + 1);
    for (const part of query.split('&')) {
      const pair: Array<string> = part.split('=');
      if (pair.length >= 2 && pair[0].toLowerCase() === 'filename') {
        try {
          return decodeURIComponent(pair.slice(1).join('='));
        } catch (error) {
          return pair.slice(1).join('=');
        }
      }
    }
  }
  return undefined;
}

function findHeaderEnd(bytes: Uint8Array): number {
  for (let index: number = 0; index + 3 < bytes.length; index++) {
    if (
      bytes[index] === 13 &&
      bytes[index + 1] === 10 &&
      bytes[index + 2] === 13 &&
      bytes[index + 3] === 10
    ) {
      return index;
    }
  }
  return -1;
}

function concatenate(first: Uint8Array, second: Uint8Array): Uint8Array {
  const output: Uint8Array = new Uint8Array(first.length + second.length);
  output.set(first, 0);
  output.set(second, first.length);
  return output;
}

function encodeUtf8(value: string): Uint8Array {
  const bytes: Array<number> = [];
  for (let index: number = 0; index < value.length; index++) {
    const code: number = value.charCodeAt(index);
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6));
      bytes.push(0x80 | (code & 0x3f));
    } else {
      bytes.push(0xe0 | (code >> 12));
      bytes.push(0x80 | ((code >> 6) & 0x3f));
      bytes.push(0x80 | (code & 0x3f));
    }
  }
  return new Uint8Array(bytes);
}

function decodeUtf8(bytes: Uint8Array): string {
  let output: string = '';
  for (let index: number = 0; index < bytes.length; index++) {
    const value: number = bytes[index];
    if (value < 0x80) {
      output += String.fromCharCode(value);
    } else if (value < 0xe0 && index + 1 < bytes.length) {
      output += String.fromCharCode(
        ((value & 0x1f) << 6) | (bytes[++index] & 0x3f)
      );
    } else if (index + 2 < bytes.length) {
      output += String.fromCharCode(
        ((value & 0x0f) << 12) |
        ((bytes[++index] & 0x3f) << 6) |
        (bytes[++index] & 0x3f)
      );
    }
  }
  return output;
}

function lastPathComponent(path: string): string {
  const normalized: string = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

function jsonEscape(value: string): string {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

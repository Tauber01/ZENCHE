import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const MAX_FILE_BYTES: number = 5 * 1024 * 1024;
const RETENTION_MILLIS: number = 14 * 24 * 60 * 60 * 1000;
const ISSUE_URL: string =
  'https://github.com/Tauber01/NikonLink/issues/new';

export class DiagnosticLogger {
  readonly directoryPath: string;
  private readonly context: common.UIAbilityContext;
  private readonly sessionId: string;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.directoryPath = `${context.filesDir}/logs`;
    this.sessionId = Date.now().toString(36).slice(-8);
    this.ensureDirectory();
    this.removeExpiredLogs();
  }

  startSession(): void {
    this.info(
      'app',
      `会话启动；版本=0.8.0 (12)；系统=HarmonyOS；会话=${this.sessionId}`
    );
  }

  endSession(): void {
    this.info('app', '会话结束');
  }

  info(category: string, message: string): void {
    this.write('INFO', category, message);
  }

  warning(category: string, message: string): void {
    this.write('WARN', category, message);
  }

  error(category: string, message: string): void {
    this.write('ERROR', category, message);
  }

  githubIssueUrl(): string {
    const body: string =
      '## 问题描述\n\n请描述发生了什么，以及如何复现。\n\n' +
      '## 环境\n\n' +
      '- 平台：HarmonyOS\n' +
      '- Nikon Link：0.8.0 (12)\n' +
      `- 会话：${this.sessionId}\n\n` +
      '## 最近诊断日志（已脱敏）\n\n```text\n' +
      this.recentText(2500) +
      '\n```\n\n' +
      '> 提交前请检查以上内容；不要填写密码、令牌或相机序列号。';
    return `${ISSUE_URL}?title=${encodeURIComponent('[HarmonyOS] ')}` +
      `&body=${encodeURIComponent(body)}`;
  }

  recentText(maxCharacters: number): string {
    this.ensureDirectory();
    let names: Array<string> = [];
    try {
      names = fs.listFileSync(this.directoryPath)
        .filter((name: string): boolean => name.toLowerCase().endsWith('.log'))
        .sort()
        .reverse();
    } catch (error) {
      hilog.warn(
        0x0000,
        'NikonLink',
        `Unable to list diagnostic logs: ${String(error)}`
      );
      return '日志暂不可用。';
    }
    let result: string = '';
    names.forEach((name: string): void => {
      if (result.length >= maxCharacters) {
        return;
      }
      const path: string = `${this.directoryPath}/${name}`;
      try {
        let text: string = fs.readTextSync(path);
        const remaining: number = maxCharacters - result.length;
        if (text.length > remaining) {
          text = text.slice(text.length - remaining);
        }
        result = text + (result.length === 0 ? '' : `\n${result}`);
      } catch (error) {
        hilog.warn(
          0x0000,
          'NikonLink',
          `Unable to read diagnostic log: ${String(error)}`
        );
      }
    });
    return result.length === 0 ? '暂无日志。' : this.redact(result);
  }

  private write(level: string, category: string, message: string): void {
    this.ensureDirectory();
    let target: string = this.currentLogPath();
    try {
      if (fs.accessSync(target) && fs.statSync(target).size >= MAX_FILE_BYTES) {
        const rotated: string =
          `${this.directoryPath}/NikonLink-${filenameTimestamp()}` +
          `-${this.sessionId}.log`;
        fs.renameSync(target, rotated);
      }
      target = this.currentLogPath();
      const cleanCategory: string = this.redact(category)
        .replace(/\s+/g, ' ');
      const cleanMessage: string = this.redact(message)
        .slice(0, 32768)
        .replaceAll('\n', '\n    ');
      const entry: string =
        `${new Date().toISOString()} [${level}] [${this.sessionId}] ` +
        `[${cleanCategory}] ${cleanMessage}\n`;
      const file: fs.File = fs.openSync(
        target,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND
      );
      try {
        fs.writeSync(file.fd, entry);
        fs.fsyncSync(file.fd);
      } finally {
        fs.closeSync(file);
      }
      if (level === 'ERROR') {
        hilog.error(0x0000, 'NikonLink', `[${category}] ${cleanMessage}`);
      } else if (level === 'WARN') {
        hilog.warn(0x0000, 'NikonLink', `[${category}] ${cleanMessage}`);
      } else {
        hilog.info(0x0000, 'NikonLink', `[${category}] ${cleanMessage}`);
      }
    } catch (error) {
      hilog.error(
        0x0000,
        'NikonLink',
        `Unable to write diagnostic log: ${String(error)}`
      );
    }
  }

  private currentLogPath(): string {
    return `${this.directoryPath}/NikonLink-${dateStamp()}.log`;
  }

  private redact(value: string): string {
    return value
      .replaceAll(this.context.filesDir, '<APP_FILES>')
      .replace(
        /((?:token|key|password|secret|serial(?: number)?|serialnumber|username)\s*[:=]\s*)\S+/gi,
        '$1<REDACTED>'
      );
  }

  private ensureDirectory(): void {
    try {
      if (!fs.accessSync(this.directoryPath)) {
        fs.mkdirSync(this.directoryPath);
      }
    } catch (error) {
      hilog.error(
        0x0000,
        'NikonLink',
        `Unable to create diagnostic directory: ${String(error)}`
      );
    }
  }

  private removeExpiredLogs(): void {
    const cutoff: number = Date.now() - RETENTION_MILLIS;
    let names: Array<string> = [];
    try {
      names = fs.listFileSync(this.directoryPath);
    } catch (error) {
      return;
    }
    names.forEach((name: string): void => {
      if (!name.toLowerCase().endsWith('.log')) {
        return;
      }
      const path: string = `${this.directoryPath}/${name}`;
      try {
        if (fs.statSync(path).mtime < cutoff) {
          fs.unlinkSync(path);
        }
      } catch (error) {
        hilog.warn(
          0x0000,
          'NikonLink',
          `Unable to remove expired diagnostic log: ${String(error)}`
        );
      }
    });
  }
}

function dateStamp(): string {
  const date: Date = new Date();
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(
    date.getDate()
  )}`;
}

function filenameTimestamp(): string {
  const date: Date = new Date();
  return `${dateStamp()}-${pad(date.getHours())}${pad(
    date.getMinutes()
  )}${pad(date.getSeconds())}`;
}

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

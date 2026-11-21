import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';


interface DavResponseHeaders {
  etag?: string;
  ETag?: string;
}

export class WebDav {
  private endpoint: string;
  private account: string;
  private password: string;

  constructor(endpoint: string, account: string, password: string) {
    this.endpoint = endpoint;
    this.account = account;
    this.password = password;
  }

  async download(): Promise<string> {
    const response = await this.request(http.RequestMethod.GET);
    if (response.responseCode !== 200 || typeof response.result !== 'string') {
      throw new Error('下载失败（HTTP ' + response.responseCode + '）');
    }
    return response.result;
  }

  async upload(body: string): Promise<void> {
    const current = await this.request(http.RequestMethod.GET);
    const conditions: Record<string, string> = { 'Content-Type': 'application/json; charset=utf-8' };
    if (current.responseCode === 404) {
      conditions['If-None-Match'] = '*';
    } else if (current.responseCode === 200) {
      const headers = current.header as DavResponseHeaders;
      const etag = headers.etag ?? headers.ETag;
      if (!etag || etag.startsWith('W/')) throw new Error('服务器未提供强 ETag，无法安全覆盖已有备份');
      conditions['If-Match'] = etag;
    } else {
      throw new Error('读取远端备份状态失败（HTTP ' + current.responseCode + '）');
    }
    const response = await this.request(http.RequestMethod.PUT, body, conditions);
    if (response.responseCode === 412) throw new Error('远端备份已变化，请先下载合并后重试');
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('上传失败（HTTP ' + response.responseCode + '）');
    }
  }

  private async request(method: http.RequestMethod, body?: string,
    headers: Record<string, string> = { 'Content-Type': 'application/json; charset=utf-8' }): Promise<http.HttpResponse> {
    if (!/^https:\/\/[^\s/?#@]+\/[^\s?#]+\.json$/i.test(this.endpoint)) {
      throw new Error('请输入以 .json 结尾的完整 HTTPS WebDAV 文件地址');
    }
    if (this.account || this.password) {
      const bytes = util.TextEncoder.create('utf-8').encodeInto(this.account + ':' + this.password);
      headers['Authorization'] = 'Basic ' + new util.Base64Helper().encodeToStringSync(bytes);
    }
    const request = http.createHttp();
    try {
      return await request.request(this.endpoint, {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000,
        maxLimit: 16 * 1024 * 1024,
        usingCache: false
      });
    } finally {
      request.destroy();
    }
  }
}

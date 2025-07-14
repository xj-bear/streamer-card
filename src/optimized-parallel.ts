// 并行优化版本 - 实现真正的并行处理
import express from 'express';
import cors from 'cors';
import puppeteer, { Browser, Page } from 'puppeteer';
import { LRUCache } from 'lru-cache';

const app = express();
const port = 3003;

// 配置参数
const isLowSpecMode = process.env.LOW_SPEC_MODE === 'true';
const scale = isLowSpecMode ? 1 : (parseFloat(process.env.IMAGE_SCALE || '2'));
const maxConcurrency = isLowSpecMode ? 1 : (parseInt(process.env.MAX_CONCURRENCY || '3'));

console.log('🚀 Optimized Parallel Service Configuration:');
console.log(`  - Low Spec Mode: ${isLowSpecMode}`);
console.log(`  - Image Scale: ${scale}`);
console.log(`  - Max Concurrency: ${maxConcurrency}`);

app.use(cors({ origin: '*' }));
app.use(express.json());

// 浏览器实例池
class BrowserPool {
    private browsers: Browser[] = [];
    private maxSize: number;
    private creating = false;

    constructor(maxSize: number = maxConcurrency) {
        this.maxSize = maxSize;
        this.preWarmPool();
    }

    private async preWarmPool() {
        if (this.creating) return;
        this.creating = true;
        
        console.log('🔥 Pre-warming browser pool...');
        const promises = [];
        for (let i = 0; i < Math.min(2, this.maxSize); i++) {
            promises.push(this.createBrowser());
        }
        
        const browsers = await Promise.all(promises);
        this.browsers.push(...browsers.filter(b => b !== null));
        this.creating = false;
        console.log(`✅ Browser pool ready with ${this.browsers.length} instances`);
    }

    private async createBrowser(): Promise<Browser | null> {
        try {
            return await puppeteer.launch({
                headless: true,
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--disable-web-security',
                    '--disable-features=VizDisplayCompositor',
                    '--disable-background-timer-throttling',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-renderer-backgrounding',
                    '--no-first-run',
                    '--no-default-browser-check',
                    '--disable-default-apps',
                    '--disable-extensions',
                    '--disable-plugins',
                    '--disable-translate',
                    '--disable-ipc-flooding-protection',
                    '--memory-pressure-off',
                    '--max_old_space_size=512'
                ],
                executablePath: process.env.PUPPETEER_EXECUTABLE_PATH,
                timeout: 30000
            });
        } catch (error) {
            console.error('Failed to create browser:', error);
            return null;
        }
    }

    async getBrowser(): Promise<Browser> {
        if (this.browsers.length > 0) {
            return this.browsers.pop()!;
        }
        
        // 如果池中没有浏览器，创建新的
        const browser = await this.createBrowser();
        if (!browser) {
            throw new Error('Failed to create browser instance');
        }
        return browser;
    }

    async returnBrowser(browser: Browser) {
        try {
            // 检查浏览器是否还活着
            const pages = await browser.pages();
            if (pages.length > 1) {
                // 关闭除第一个页面外的所有页面
                for (let i = 1; i < pages.length; i++) {
                    await pages[i].close();
                }
            }
            
            if (this.browsers.length < this.maxSize) {
                this.browsers.push(browser);
            } else {
                await browser.close();
            }
        } catch (error) {
            console.error('Error returning browser to pool:', error);
            try {
                await browser.close();
            } catch {}
        }
    }

    async cleanup() {
        const browsers = [...this.browsers];
        this.browsers = [];
        await Promise.all(browsers.map(browser => browser.close().catch(() => {})));
    }
}

// 页面模板缓存
class TemplateCache {
    private cache = new LRUCache<string, string>({
        max: 50,
        ttl: 300 * 1000 // 5分钟
    });

    async getTemplate(url: string): Promise<string> {
        const cached = this.cache.get(url);
        if (cached) {
            return cached;
        }
        
        // 这里可以预加载模板内容
        // 目前返回URL，实际使用时页面会加载
        this.cache.set(url, url);
        return url;
    }
}

// 结果缓存
const resultCache = new LRUCache<string, Buffer>({
    max: 20,
    maxSize: 20 * 1024 * 1024, // 20MB
    sizeCalculation: (value: Buffer) => value.length,
    ttl: 300 * 1000 // 5分钟
});

// 初始化
const browserPool = new BrowserPool();
const templateCache = new TemplateCache();

// 并行图片生成函数
async function generateImageParallel(requestData: any): Promise<Buffer> {
    const cacheKey = JSON.stringify(requestData);
    
    // 检查缓存
    const cached = resultCache.get(cacheKey);
    if (cached) {
        console.log('📦 Cache hit');
        return cached;
    }

    const browser = await browserPool.getBrowser();
    let page: Page | null = null;
    
    try {
        // 并行执行的任务
        const [pageReady, templateReady] = await Promise.all([
            browser.newPage(),
            templateCache.getTemplate('https://fireflycard.shushiai.com/zh/reqApi')
        ]);
        
        page = pageReady;
        
        // 并行设置页面配置
        await Promise.all([
            page.setViewport({ width: 1920, height: 1080 }),
            page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'),
            page.setExtraHTTPHeaders({
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
            })
        ]);

        // 构建URL
        const params = new URLSearchParams({
            isApi: 'true',
            ...requestData
        });
        const finalUrl = `${templateReady}?${params.toString()}`;
        
        console.log(`🌐 Loading: ${finalUrl}`);
        
        // 导航到页面
        await page.goto(finalUrl, {
            waitUntil: 'networkidle0',
            timeout: 60000
        });

        // 等待卡片元素并获取边界框
        const cardSelector = '.card-container, .card, [class*="card"]';
        await page.waitForSelector(cardSelector, { timeout: 30000 });
        
        const element = await page.$(cardSelector);
        if (!element) {
            throw new Error('Card element not found');
        }

        const boundingBox = await element.boundingBox();
        if (!boundingBox) {
            throw new Error('Could not get element bounding box');
        }

        console.log(`📏 Bounding box: ${JSON.stringify(boundingBox)}`);
        console.log(`🔍 Image scale: ${scale}`);

        // 截图
        const buffer = await page.screenshot({
            type: 'png',
            clip: {
                x: boundingBox.x,
                y: boundingBox.y,
                width: boundingBox.width,
                height: boundingBox.height,
                scale: scale
            }
        });

        console.log(`✅ Screenshot captured: ${buffer.length} bytes`);
        
        // 缓存结果
        resultCache.set(cacheKey, buffer);
        
        return buffer;
        
    } finally {
        if (page) {
            await page.close().catch(() => {});
        }
        await browserPool.returnBrowser(browser);
    }
}

// API路由
app.get('/api', (req, res) => {
    res.json({ status: 'ok', message: 'Optimized Parallel Service' });
});

app.post('/api/saveImg', async (req, res) => {
    const startTime = Date.now();
    
    try {
        console.log(`🚀 Processing request: ${JSON.stringify(req.body)}`);
        
        const buffer = await generateImageParallel(req.body);
        
        const duration = Date.now() - startTime;
        console.log(`⚡ Request completed in ${duration}ms`);
        
        res.set({
            'Content-Type': 'image/png',
            'Content-Length': buffer.length,
            'X-Generation-Time': duration.toString()
        });
        
        res.send(buffer);
        
    } catch (error) {
        const duration = Date.now() - startTime;
        console.error(`❌ Request failed after ${duration}ms:`, error);
        
        res.status(500).json({
            error: 'Image generation failed',
            message: error instanceof Error ? error.message : 'Unknown error',
            duration
        });
    }
});

// 优雅关闭
process.on('SIGTERM', async () => {
    console.log('🛑 Shutting down gracefully...');
    await browserPool.cleanup();
    process.exit(0);
});

process.on('SIGINT', async () => {
    console.log('🛑 Shutting down gracefully...');
    await browserPool.cleanup();
    process.exit(0);
});

app.listen(port, () => {
    console.log(`🚀 Optimized Parallel Service listening on port ${port}`);
});

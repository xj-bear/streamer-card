// 引入 Puppeteer Cluster 库，用于并发浏览器任务
import MarkdownIt from "markdown-it"; // 引入 Markdown-It 库，用于解析 Markdown 语法
import cors from 'cors'; // 引入 cors 中间件

// 引入 Express 框架
import {Cluster} from "puppeteer-cluster";
import express from "express";
// 初始化 Markdown-It，并设置换行符解析选项
import {LRUCache} from "lru-cache"; // 引入 LRU 缓存库，并注意其导入方式
import {markdownItTable} from 'markdown-it-table';

const md = new MarkdownIt({
    html: true, // 允许 markdown 文本使用 html 标签
    linkify: false, // 禁用自动转换 URL
    typographer: true,// 智能排版
}).use(markdownItTable);

const port = 3003; // 设置服务器监听端口
let url = 'https://fireflycard.shushiai.com/zh/reqApi'; // 要访问的目标 URL
// let url = 'http://localhost:3001/zh/reqApi'; // 要访问的目标 URL
// 低配置模式优化参数
const isLowSpecMode = process.env.LOW_SPEC_MODE === 'true';
const scale = isLowSpecMode ? 1 : (parseFloat(process.env.IMAGE_SCALE || '2')); // 低配置模式使用1x缩放，支持小数
const maxRetries = isLowSpecMode ? 1 : (parseInt(process.env.MAX_RETRIES || '2')); // 低配置模式减少重试
const maxConcurrency = isLowSpecMode ? 1 : (parseInt(process.env.MAX_CONCURRENCY || (process.env.NODE_ENV === 'production' ? '2' : '5'))); // 低配置模式单并发

// 启动时显示配置信息
console.log('🚀 Streamer Card Service Configuration:');
console.log(`  - Low Spec Mode: ${isLowSpecMode}`);
console.log(`  - Image Scale: ${scale}`);
console.log(`  - Max Concurrency: ${maxConcurrency}`);
console.log(`  - Max Retries: ${maxRetries}`);
console.log(`  - NODE_ENV: ${process.env.NODE_ENV}`);

const app = express(); // 创建 Express 应用

// 配置 CORS 中间件，允许所有跨域请求
app.use(cors({
    origin: '*', // 允许任何来源
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'], // 允许的 HTTP 方法
    allowedHeaders: ['Content-Type', 'Authorization'] // 允许的请求头
}));

app.use(express.json()); // 使用 JSON 中间件
app.use(express.urlencoded({extended: false})); // 使用 URL 编码中间件

let cluster; // 定义 Puppeteer 集群变量

// 请求队列管理
let activeRequests = 0;
const maxActiveRequests = process.env.NODE_ENV === 'production' ? 2 : 3;
const requestQueue: Array<{ resolve: Function, reject: Function }> = [];

// 设置 LRU 缓存，针对低内存环境优化
const cache = new LRUCache({
    max: process.env.NODE_ENV === 'production' ? 20 : 50, // 生产环境减少缓存项
    maxSize: process.env.NODE_ENV === 'production' ? 20 * 1024 * 1024 : 50 * 1024 * 1024, // 生产环境减少缓存大小
    sizeCalculation: (value: any, key: any) => {
        return value.length; // 缓存项大小计算方法
    },
    ttl: 300 * 1000, // 缓存项 5 分钟后过期，减少内存占用
    allowStale: false, // 不允许使用过期的缓存项
    updateAgeOnGet: true, // 获取缓存项时更新其年龄
});

// 初始化 Puppeteer 集群
async function initCluster() {
    cluster = await Cluster.launch({
        concurrency: Cluster.CONCURRENCY_CONTEXT, // 使用上下文并发模式
        maxConcurrency: maxConcurrency, // 设置最大并发数
        timeout: parseInt(process.env.PROTOCOL_TIMEOUT || (isLowSpecMode ? '120000' : '60000')), // 设置任务超时
        puppeteerOptions: {
            executablePath: process.env.PUPPETEER_EXECUTABLE_PATH ||
                           (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' :
                            process.platform === 'win32' ? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe' : undefined),
            args: [
                // Docker环境必需参数
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',

                // 基础headless配置
                '--disable-gpu',
                '--disable-web-security',
                '--no-first-run',
                '--disable-extensions',
                '--disable-default-apps',
                '--hide-scrollbars',
                '--mute-audio',

                // 性能优化
                '--disable-background-networking',
                '--disable-background-timer-throttling',
                '--disable-renderer-backgrounding',
                '--disable-backgrounding-occluded-windows',

                // 功能禁用
                '--disable-translate',
                '--disable-sync',
                '--disable-plugins',

                // 低配置模式额外优化
                ...(isLowSpecMode ? [
                    '--memory-pressure-off',
                    '--disable-features=VizDisplayCompositor',
                    '--disable-ipc-flooding-protection',
                    '--disable-background-media-suspend',
                    '--disable-component-extensions-with-background-pages',
                    '--disable-client-side-phishing-detection'
                ] : [])
            ],
            headless: true, // 无头模式
            protocolTimeout: parseInt(process.env.PROTOCOL_TIMEOUT || (isLowSpecMode ? '45000' : '60000')), // 使用环境变量配置的协议超时
            defaultViewport: { width: 1920, height: 1080 } // 设置默认视口
        }
    });

    // 处理任务错误
    cluster.on('taskerror', (err, data) => {
        console.error(`任务处理错误: ${data}: ${err.message}`);
    });

    console.log('Puppeteer 集群已启动');
}

// 请求限流函数
function acquireRequestSlot(): Promise<void> {
    return new Promise((resolve, reject) => {
        if (activeRequests < maxActiveRequests) {
            activeRequests++;
            resolve();
        } else {
            // 添加到队列
            requestQueue.push({ resolve, reject });

            // 设置超时，避免无限等待
            setTimeout(() => {
                const index = requestQueue.findIndex(item => item.resolve === resolve);
                if (index !== -1) {
                    requestQueue.splice(index, 1);
                    reject(new Error('请求队列超时，服务器繁忙，请稍后重试'));
                }
            }, parseInt(process.env.PROTOCOL_TIMEOUT || (isLowSpecMode ? '120000' : '60000'))); // 使用环境变量配置的超时
        }
    });
}

// 释放请求槽位
function releaseRequestSlot() {
    activeRequests--;
    if (requestQueue.length > 0) {
        const next = requestQueue.shift();
        if (next) {
            activeRequests++;
            next.resolve();
        }
    }
}

// 生成请求唯一标识符
function generateCacheKey(body) {
    return JSON.stringify(body); // 将请求体序列化为字符串
}

// 处理请求的主要逻辑
async function processRequest(body) {
    const cacheKey = generateCacheKey(body); // 生成缓存键

    // 检查缓存中是否有结果
    const cachedResult = cache.get(cacheKey);
    if (cachedResult) {
        console.log('从缓存中获取结果');
        return cachedResult; // 返回缓存结果
    }

    // 获取请求槽位
    await acquireRequestSlot();

    try {
        // 根据语言初始化链接
        let language = body?.language;
        if (language) {
            url = url.replace('zh',language)
        }

    console.log('处理请求，内容为:', JSON.stringify(body));
    // 是否使用字体
    let useLoadingFont = body.useLoadingFont;

    let params = new URLSearchParams(); // 初始化 URL 查询参数

    params.append("isApi", "true")

    let blackArr: string[] = ['icon', 'translate', 'content']; // 定义不需要加入查询参数的键

    let translate = body.translate;
    if (!translate) {
        translate = body?.form?.translate
    }

    let content = body.content;
    if (!content) {
        content = body?.form?.content
    }

    let iconSrc = body.icon;
    if (!iconSrc) {
        iconSrc = body?.form?.icon
    }

    for (const key in body) {
        let value = body[key];
        if (!blackArr.includes(key)) {
            if (key === 'switchConfig' || key === 'fonts' || key === 'style') {
                let valueStr = JSON.stringify(value);
                console.log('valueStr',valueStr)
                params.append(key, valueStr); // 序列化 switchConfig
            } else if(key === 'form'){
                delete value.content;
                delete value.translate;
                delete value.iconSrc;
                let valueStr = JSON.stringify(value);
                console.log('FormValueStr',valueStr)
                params.append(key, valueStr);
            } else{
                params.append(key, value);
            }
        }
    }

    let finalUrl = url + '?' + params.toString();


    console.log('finalUrl', finalUrl);

    const result = await cluster.execute({
        url: url + '?' + params.toString(), // 拼接 URL 和查询参数
        body,
        iconSrc,
    }, async ({page, data}) => {
        const {url, body, iconSrc} = data;
        await page.setRequestInterception(true); // 设置请求拦截
        page.on('request', req => {
            req.continue();
        });

        const viewPortConfig = {width: 1920, height: 1080}; // 设置视口配置
        await page.setViewport(viewPortConfig); // 应用视口配置
        console.log('视口设置为:', viewPortConfig);

        await page.goto(url, {
            timeout: parseInt(process.env.NAVIGATION_TIMEOUT || (isLowSpecMode ? '90000' : '120000')), // 使用环境变量配置的导航超时
            waitUntil: isLowSpecMode ? ['load'] : ['load', 'domcontentloaded'] // 优化等待条件，使用domcontentloaded替代networkidle2
        });
        console.log('页面已导航至:', url);

        // 优化所有模式的等待时间
        await delay(isLowSpecMode ? 1000 : 1500)

        // 这里因为字体是按需加载，所以前面的等待字体加载不太有效，这里增大等待时间，以免部分字体没有加载完成
        // const cardElement = await page.$(`#${body.temp || 'tempA'}`); // 查找卡片元素
        const cardElement = await page.$(`.${body.temp || 'tempA'}`); // 查找卡片元素
        // const cardElement = await page.$(`.content-mode`);
        if (!cardElement) {
            throw new Error('请求的卡片不存在'); // 抛出错误
        }
        console.log('找到卡片元素');

        if (translate) {
            await page.evaluate((translate: string) => {
                // 如果有英文翻译插入英文翻译
                const translateEl = document.querySelector('[name="showTranslation"]');
                if (translateEl) translateEl.innerHTML = translate;
            }, translate);
        }

        let isContentHtml: boolean = body.isContentHtml;
        if (content) {
            let html = content;
            if (!isContentHtml) {
                html = md.render(content);
                html = `<div data-v-fc3bb97c="" contenteditable="true" translate="no" name="editableText" class="editable-element md-class">${html}</div>`
            }
            await page.evaluate(html => {
                // 插入内容
                const contentEl = document.querySelector('[name="showContent"]');
                if (contentEl) contentEl.innerHTML = html;
            }, html);
            console.log('卡片内容已设置');

            // 等待内容中的图片加载完成
            await page.evaluate(() => {
                return new Promise((resolve) => {
                    const images = document.querySelectorAll('[name="showContent"] img');
                    if (images.length === 0) {
                        resolve(true);
                        return;
                    }

                    let loadedCount = 0;
                    const totalImages = images.length;

                    const checkComplete = () => {
                        loadedCount++;
                        if (loadedCount >= totalImages) {
                            resolve(true);
                        }
                    };

                    images.forEach((img: any) => {
                        if (img.complete) {
                            checkComplete();
                        } else {
                            img.addEventListener('load', checkComplete);
                            img.addEventListener('error', checkComplete);
                        }
                    });

                    // 设置超时，避免无限等待，优化所有模式的等待时间
                    setTimeout(() => resolve(true), isLowSpecMode ? 5000 : 6000);
                });
            });
            console.log('内容图片加载完成');

            // 额外等待，确保布局重新计算完成，优化所有模式的等待时间
            await delay(isLowSpecMode ? 500 : 1000);
        }

        if (iconSrc && iconSrc.startsWith('http')) {
            await page.evaluate(function (imgSrc) {
                return new Promise(function (resolve) {
                    let imageElement: any = document.querySelector('#icon');
                    console.log("头像", imageElement);
                    if (imageElement) {
                        imageElement.src = imgSrc;
                        imageElement.addEventListener('load', function () {
                            resolve(true);
                        });
                        imageElement.addEventListener('error', function () {
                            resolve(true);
                        });
                    } else {
                        resolve(false);
                    }
                });
            }, iconSrc);
            console.log('图标已设置');
        }

        // 等待页面布局稳定，确保所有内容都已渲染
        await page.waitForFunction(() => {
            return document.readyState === 'complete';
        }, { timeout: parseInt(process.env.SCREENSHOT_TIMEOUT || (isLowSpecMode ? '60000' : '60000')) });

        // 智能等待 - 检测关键元素是否已渲染（所有模式）
        try {
            await page.waitForFunction(() => {
                const cardEl = document.querySelector('.tempA');
                const contentEl = document.querySelector('[name="showContent"]');
                return cardEl && contentEl && contentEl.children.length > 0;
            }, { timeout: isLowSpecMode ? 5000 : 8000 });
            console.log('智能等待：关键元素已渲染');
        } catch (e) {
            console.log('智能等待超时，继续执行');
        }

        // 额外等待确保动态内容渲染完成，优化所有模式的等待时间
        await delay(isLowSpecMode ? 1000 : 1500);

        const boundingBox = await cardElement.boundingBox(); // 获取卡片元素边界框
        console.log('boundingBox', boundingBox);

        // 验证边界框是否合理
        if (!boundingBox || boundingBox.height < 100) {
            console.error('边界框异常，重新获取');
            await delay(isLowSpecMode ? 1000 : 1500);
            const retryBoundingBox = await cardElement.boundingBox();
            console.log('重试后的boundingBox', retryBoundingBox);
            if (retryBoundingBox && retryBoundingBox.height > boundingBox?.height) {
                Object.assign(boundingBox, retryBoundingBox);
            }
        }

        let imgScale = body.imgScale ? body.imgScale : scale;

        if (boundingBox.height > viewPortConfig.height) {
            console.log('卡片高度大于视口高度，需要截取图片',boundingBox.height);
            // 使用 Math.ceil 向上取整，确保不丢失任何像素
            // 增加更大的缓冲区（600px）以确保二维码等底部内容完整显示
            const newHeight = Math.ceil(boundingBox.height) + 600;
            await page.setViewport({
                width: 1920,
                height: newHeight
            });
            console.log('调整视口高度:', newHeight);

            // 调整视口后等待重新渲染，优化所有模式的等待时间
            await delay(isLowSpecMode ? 500 : 1000);
        }

        // 在调整视口后重新获取边界框，确保位置准确
        const finalBoundingBox = await cardElement.boundingBox();
        console.log('最终边界框:', finalBoundingBox);

        // 检查内容是否完整渲染（通过检查特定文本是否存在）
        const contentCheck = await page.evaluate(() => {
            const contentEl = document.querySelector('[name="showContent"]');
            if (contentEl) {
                const text = contentEl.textContent || '';
                const hasConclusion = text.includes('如果您能看到这段文字，说明高度自适应功能工作正常');
                const hasQRCode = document.querySelector('[name="showContent"]') &&
                                 document.querySelector('*[class*="qr"], *[id*="qr"], *[class*="code"]');
                return {
                    textLength: text.length,
                    hasConclusion,
                    hasQRCode: !!hasQRCode,
                    fullText: text.substring(text.length - 100) // 最后100个字符
                };
            }
            return { textLength: 0, hasConclusion: false, hasQRCode: false, fullText: '' };
        });
        console.log('内容完整性检查:', contentCheck);

        // 如果内容不完整，等待更长时间，优化所有模式的等待时间
        if (!contentCheck.hasConclusion) {
            console.log('内容可能不完整，等待更长时间...');
            await delay(isLowSpecMode ? 2000 : 3000);
            const retryBoundingBox = await cardElement.boundingBox();
            console.log('重试后边界框:', retryBoundingBox);
            if (retryBoundingBox && retryBoundingBox.height > finalBoundingBox.height) {
                Object.assign(finalBoundingBox, retryBoundingBox);
                console.log('使用重试后的边界框');
            }
        }

        console.log('图片缩放比例为:', imgScale)
        const buffer = await page.screenshot({
            type: 'png', // 设置截图格式为 PNG
            clip: {
                x: finalBoundingBox.x,
                y: finalBoundingBox.y,
                width: finalBoundingBox.width,
                height: finalBoundingBox.height,
                scale: imgScale // 设置截图缩放比例
            },
            timeout: parseInt(process.env.SCREENSHOT_TIMEOUT || (isLowSpecMode ? '60000' : '60000')), // 使用环境变量配置的截图超时
        });
        console.log('截图已捕获');

        return buffer; // 返回截图
    });

    // 检查缓存大小，确保不会超过限制
    const currentCacheSize = cache.size;
    if (currentCacheSize + result.length <= cache.maxSize) {
        // 将结果缓存
        cache.set(cacheKey, result);
    } else {
        console.warn('缓存已满，无法缓存新的结果');
    }

        // 释放请求槽位
        releaseRequestSlot();

        return result; // 返回处理结果
    } catch (error) {
        // 确保在错误情况下也释放槽位
        releaseRequestSlot();
        throw error;
    }
}

/**4
 * 写一个对象数组，包含三个属性
 * qrcodetitle 二维码头部
 * qrcodetext 二维码描述文字
 * qrcode 你的二维码链接
 */
const qrcodeArr:any[] = [
    {
        qrcodetitle: '流光卡片',
        qrcodetext: '让分享更美好',
        qrcode: 'https://textcard.shushiai.com/zh'
    },
    {
        qrcodetitle: '扫码添加微信',
        qrcodetext: '插件作者：嵬hacking',
        qrcode: 'https://u.wechat.com/MLY1YU64xqoNul2tibIJo6A'
    }
]


async function saveImgHandle(req: any, res: any, flag: boolean) {
    let body = req.body;
    if (flag) {
        // 随机从 qrcodeArr 中抽取一个元素
        const qrcodeObj = qrcodeArr[Math.floor(Math.random() * qrcodeArr.length)];
        // 覆盖 body 中对应的元素属性
        body.qrcodetitle = qrcodeObj.qrcodetitle;
        body.qrcodetext = qrcodeObj.qrcodetext;
        body.qrcode = qrcodeObj.qrcode;
    }
    let attempts = 0;
    while (attempts < maxRetries) {
        try {
            const buffer = await processRequest(body); // 处理请求
            res.setHeader('Content-Type', 'image/png'); // 设置响应头
            res.status(200).send(buffer); // 发送响应
            return;
        } catch (error) {
            console.error(`第 ${attempts + 1} 次尝试失败:`, error);
            attempts++;
            if (attempts >= maxRetries) {
                res.status(500).send(`处理请求失败，已重试 ${maxRetries} 次`); // 发送错误响应
            } else {
                await delay(1000); // 等待一秒后重试
            }
        }
    }
}

// 处理保存图片的 POST 请求
app.post('/api/saveImg', async (req: any, res: any) => {
    await saveImgHandle(req, res, false)
});

// 广告位请求
app.post('/api/wxSaveImg', async (req: any, res: any) => {
    await saveImgHandle(req, res, true)
});

// 写一个接口，不需要任何 uri，请求端口，返回 hello world
app.get('/api', (req, res) => {
    res.send('hello world');
});

// 处理进程终止信号
process.on('SIGINT', async () => {
    await cluster.idle(); // 等待所有任务完成
    await cluster.close(); // 关闭 Puppeteer 集群
    process.exit(); // 退出进程
});

// 启动服务器并初始化 Puppeteer 集群
app.listen(port, async () => {
    console.log(`监听端口 ${port}...`);
    await initCluster();
});

// 延迟函数，用于等待指定的毫秒数
function delay(timeout: number) {
    return new Promise(resolve => setTimeout(resolve, timeout));
}


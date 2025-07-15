@echo off
echo 开始性能测试...
echo.

echo 测试时间: %date% %time%
echo.

echo 发送请求到 http://localhost:9200/api/saveImg
echo.

curl -X POST http://localhost:9200/api/saveImg ^
     -H "Content-Type: application/json" ^
     -d @test_data.json ^
     -o test_optimized_result.png ^
     --max-time 180 ^
     -w "HTTP状态码: %%{http_code}\n响应时间: %%{time_total}秒\n文件大小: %%{size_download}字节\n"

echo.
echo 测试完成!

if exist test_optimized_result.png (
    echo 生成的图片文件: test_optimized_result.png
    for %%A in (test_optimized_result.png) do echo 文件大小: %%~zA 字节
) else (
    echo 错误: 未生成图片文件
)

pause

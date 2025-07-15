@echo off
echo 测试优化后的标准模式性能...
echo.

echo 开始时间: %time%
echo.

curl -X POST http://localhost:9200/api/saveImg ^
     -H "Content-Type: application/json" ^
     -d @test_data.json ^
     -o test_standard_optimized.png ^
     --max-time 180 ^
     -w "HTTP状态码: %%{http_code}\n响应时间: %%{time_total}秒\n"

echo.
echo 结束时间: %time%
echo.

if exist test_standard_optimized.png (
    echo 成功生成图片: test_standard_optimized.png
    for %%A in (test_standard_optimized.png) do echo 文件大小: %%~zA 字节
) else (
    echo 错误: 未生成图片文件
)

echo.
echo 测试完成!

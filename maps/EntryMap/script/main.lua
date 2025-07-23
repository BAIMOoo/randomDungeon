-- 游戏启动后会自动运行此文件

--在开发模式下，将日志打印到游戏中
if y3.game.is_debug_mode() then
    y3.config.log.toGame = true
    y3.config.log.level  = 'debug'
else
    y3.config.log.toGame = false
    y3.config.log.level  = 'info'
end

y3.game:event('游戏-初始化', function (trg, data)
    print('Hello, Y3!')
end)


-- 此文件内的代码可以被热重载
include '可重载的代码'
include 'dungeonGenerate'
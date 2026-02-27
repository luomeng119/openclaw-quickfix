# OpenClaw QuickFix 使用示例

本目录包含 openclaw-terminal.sh 的使用示例，展示不同场景下的终端分屏布局。

## 运行示例

```bash
# 进入示例目录
cd examples

# 示例1: 2窗格简单布局
./example-01-simple.sh

# 示例2: 3窗格标准布局
./example-02-standard.sh

# 示例3: 6窗格调试布局
./example-03-debug.sh

# 示例4: SmartFix 场景模拟
./example-04-smartfix.sh
```

## 示例说明

### example-01-simple.sh
**2窗格简单布局**
- 窗格1: 主命令执行
- 窗格2: 日志监控

适用场景：简单的命令执行和输出监控

### example-02-standard.sh
**3窗格标准布局**
- 窗格1: 主命令执行
- 窗格2: 日志监控
- 窗格3: 状态监控

适用场景：SmartFix 修复过程可视化

### example-03-debug.sh
**6窗格调试布局**
- 窗格1: 主命令执行
- 窗格2: 日志监控
- 窗格3: 状态监控
- 窗格4: 配置文件查看
- 窗格5: 服务状态
- 窗格6: 网络端口监控

适用场景：深度调试，需要同时查看多个信息源

### example-04-smartfix.sh
**SmartFix 场景模拟**
演示如何在实际修复场景中使用可视化终端

## 注意事项

- macOS: 需要安装 iTerm
- Linux/Windows: 需要安装 tmux
- 运行示例时会实际打开终端窗口

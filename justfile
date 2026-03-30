app     := "enotes"
release := "build/macos/Build/Products/Release/" + app + ".app/"
install := "/Applications/" + app + ".app"

# 列出所有可用命令
default:
    @just --list

# 构建 release 包
build:
    flutter build macos --release

# 停止正在运行的程序
stop:
    @pkill -x "{{ app }}" && echo "已停止 {{ app }}" || echo "{{ app }} 未在运行"

# 安装到 /Applications（需先 build）
install: stop
    rsync -av --delete "{{ release }}" "{{ install }}"
    @echo "已安装到 {{ install }}"

# 启动
run:
    open "{{ install }}"

# 构建 → 安装 → 启动（一键重新部署）
deploy: build install run

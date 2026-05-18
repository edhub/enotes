app     := "enotes"
release := "build/macos/Build/Products/Release/" + app + ".app/"
install := "/Applications/" + app + ".app"

# 列出所有可用命令
default:
    @just --list

# 代码格式化
format:
    dart format lib test

# 自动应用可安全修复
fix:
    dart fix --apply

# 静态检查（应 0 issues）
analyze:
    flutter analyze

# 跑全部单元测试
test:
    flutter test

# 一键检查：analyze + test，提交前跑
check: analyze test

# 构建 macOS release 包
build:
    flutter build macos --release

# 构建 web release 包（--pwa-strategy=none 禁用 Flutter 废弃的内置 SW，改用 web/sw.js）
build-web:
    flutter build web --release --no-tree-shake-icons --pwa-strategy=none

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

# 构建 → 安装 → 启动（一键重新部署 macOS）
deploy: build install run

# 构建 web 并部署到 ali44（部署前自动 bump sw.js 缓存版本，确保旧缓存被清除）
deploy-web: build-web
    sed -i '' "s/enotes-v1/enotes-v$(date +%Y%m%d%H%M%S)/" build/web/sw.js
    rsync -r --delete build/web/ ali44:/var/www/enotes/public

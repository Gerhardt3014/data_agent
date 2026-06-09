#!/usr/bin/env bash
#
# MySQL 自动安装脚本
# 适用系统: Ubuntu 24.04 (WSL2)
# 用法: sudo bash install_mysql.sh
#

set -euo pipefail

# ======================== 配置区 ========================
MYSQL_ROOT_PASSWORD=""        # 留空则交互式输入
NEW_USER=""                   # 新建用户名，留空则跳过
NEW_USER_PASSWORD=""          # 新用户密码，留空则交互式输入
MYSQL_VERSION=""              # 指定版本如 "8.0"，留空则安装默认版本
# ========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---------- 检查 root 权限 ----------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 sudo 运行此脚本: sudo bash $0"
    fi
}

# ---------- 检测系统 ----------
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-unknown}"
    else
        error "无法检测操作系统版本"
    fi
    info "检测到系统: ${PRETTY_NAME:-$OS_ID $OS_VERSION}"

    if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "debian" ]]; then
        warn "此脚本主要针对 Ubuntu/Debian，在其他系统上可能不兼容"
    fi
}

# ---------- 检查是否已安装 ----------
check_existing() {
    if command -v mysql &>/dev/null; then
        local ver
        ver=$(mysql --version 2>/dev/null || echo "unknown")
        warn "MySQL 已安装: $ver"
        read -rp "是否重新安装? [y/N]: " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            info "跳过安装"
            exit 0
        fi
    fi
}

# ---------- 更新系统包 ----------
update_system() {
    info "更新软件包列表..."
    apt-get update -y
}

# ---------- 安装 MySQL ----------
install_mysql() {
    info "安装 MySQL Server..."
    if [[ -n "$MYSQL_VERSION" ]]; then
        local pkg="mysql-server-${MYSQL_VERSION}"
        info "尝试安装指定版本: $pkg"
        apt-get install -y "$pkg" 2>/dev/null || {
            warn "指定版本 ${MYSQL_VERSION} 不可用，安装默认版本"
            apt-get install -y mysql-server
        }
    else
        apt-get install -y mysql-server
    fi
    info "MySQL 安装完成"
}

# ---------- 启动服务 ----------
start_service() {
    info "启动 MySQL 服务..."
    if systemctl &>/dev/null; then
        systemctl start mysql
        systemctl enable mysql 2>/dev/null || true
    else
        # WSL2 环境通常使用 service 命令
        service mysql start
    fi
    info "MySQL 服务已启动"
}

# ---------- 配置 root 密码 ----------
configure_root() {
    info "配置 root 用户..."

    # 检查当前 root 认证方式
    local auth_plugin
    auth_plugin=$(mysql -u root -e "SELECT plugin FROM mysql.user WHERE user='root';" -s -N 2>/dev/null || echo "")

    if [[ "$auth_plugin" == "auth_socket" ]]; then
        info "当前 root 使用 auth_socket 认证（无需密码即可 sudo 登录）"
        read -rp "是否为 root 设置密码认证? [y/N]: " set_pwd
        if [[ "$set_pwd" =~ ^[Yy]$ ]]; then
            if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
                read -rsp "请输入 root 密码: " MYSQL_ROOT_PASSWORD
                echo
                read -rsp "请确认 root 密码: " confirm
                echo
                [[ "$MYSQL_ROOT_PASSWORD" != "$confirm" ]] && error "两次密码不一致"
            fi
            mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${MYSQL_ROOT_PASSWORD}';"
            info "root 密码已设置"
        fi
    else
        if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
            read -rsp "请输入 root 密码: " MYSQL_ROOT_PASSWORD
            echo
        fi
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || \
            mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null && info "root 密码已就绪"
    fi
}

# ---------- 创建新用户 ----------
create_user() {
    if [[ -z "$NEW_USER" ]]; then
        read -rp "是否创建新的 MySQL 用户? [y/N]: " create
        if [[ ! "$create" =~ ^[Yy]$ ]]; then
            return
        fi
        read -rp "请输入新用户名: " NEW_USER
    fi

    if [[ -z "$NEW_USER_PASSWORD" ]]; then
        read -rsp "请输入 ${NEW_USER} 的密码: " NEW_USER_PASSWORD
        echo
    fi

    local root_args="-u root"
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        root_args="-u root -p${MYSQL_ROOT_PASSWORD}"
    fi

    mysql $root_args -e "
        CREATE USER IF NOT EXISTS '${NEW_USER}'@'localhost' IDENTIFIED BY '${NEW_USER_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO '${NEW_USER}'@'localhost';
        FLUSH PRIVILEGES;
    "
    info "用户 '${NEW_USER}' 已创建并授权"
}

# ---------- 安全加固 ----------
secure_installation() {
    info "执行安全加固..."
    local root_args="-u root"
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        root_args="-u root -p${MYSQL_ROOT_PASSWORD}"
    fi

    mysql $root_args -e "
        -- 删除匿名用户
        DELETE FROM mysql.user WHERE user='';

        -- 禁止 root 远程登录
        DELETE FROM mysql.user WHERE user='root' AND host NOT IN ('localhost', '127.0.0.1', '::1');

        -- 删除测试数据库
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

        FLUSH PRIVILEGES;
    "
    info "安全加固完成"
}

# ---------- WSL2 开机自启配置 ----------
setup_wsl_autostart() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        info "检测到 WSL2 环境"
        read -rp "是否配置 WSL2 开机自动启动 MySQL? [y/N]: " auto_start
        if [[ "$auto_start" =~ ^[Yy]$ ]]; then
            local rc_file="/home/${SUDO_USER:-$USER}/.bashrc"
            local marker="# >>> mysql-autostart >>>"
            if ! grep -q "$marker" "$rc_file" 2>/dev/null; then
                cat >> "$rc_file" << 'AUTOSTART'

# >>> mysql-autostart >>>
# 自动启动 MySQL 服务（仅 WSL2）
if grep -qi microsoft /proc/version 2>/dev/null; then
    if ! service mysql status &>/dev/null; then
        sudo service mysql start &>/dev/null
    fi
fi
# <<< mysql-autostart <<<
AUTOSTART
                info "已将 MySQL 自启动写入 ${rc_file}"
                info "提示: 建议配置 sudo 免密码以实现无感启动"
                info "  运行: sudo visudo -f /etc/sudoers.d/mysql"
                info "  添加: ${SUDO_USER:-$USER} ALL=(root) NOPASSWD: /usr/sbin/service mysql start"
            else
                info "自启动配置已存在，跳过"
            fi
        fi
    fi
}

# ---------- 验证安装 ----------
verify() {
    echo ""
    echo "========================================"
    info "MySQL 安装验证"
    echo "========================================"

    local ver
    ver=$(mysql --version 2>/dev/null)
    info "版本: $ver"

    if service mysql status &>/dev/null || systemctl is-active mysql &>/dev/null; then
        info "服务状态: 运行中"
    else
        warn "服务状态: 未运行"
    fi

    info "监听端口: $(ss -tlnp 2>/dev/null | grep mysql | awk '{print $4}' || echo "3306")"

    echo ""
    info "安装完成! 常用命令:"
    echo "  登录:          sudo mysql -u root -p"
    echo "  启动服务:      sudo service mysql start"
    echo "  停止服务:      sudo service mysql stop"
    echo "  重启服务:      sudo service mysql restart"
    echo "  查看状态:      sudo service mysql status"
    echo "  配置文件:      /etc/mysql/mysql.conf.d/mysqld.cnf"
    echo "  数据目录:      /var/lib/mysql"
    echo "========================================"
}

# ======================== 主流程 ========================
main() {
    echo ""
    echo "========================================"
    echo "  MySQL 自动安装脚本"
    echo "  系统: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "========================================"
    echo ""

    check_root
    detect_os
    check_existing
    update_system
    install_mysql
    start_service
    configure_root
    create_user
    secure_installation
    setup_wsl_autostart
    verify
}

main "$@"

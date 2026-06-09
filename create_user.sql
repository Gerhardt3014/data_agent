-- ============================================================
-- 创建 MySQL 用户 hgh 并授权
-- 执行方式: sudo mysql < create_user.sql
-- ============================================================

-- 创建用户（允许本地连接，密码为 hgh123456）
CREATE USER IF NOT EXISTS 'hgh'@'localhost' IDENTIFIED BY 'hgh123456';

-- 授予所有权限（包含创建数据库的权限）
GRANT ALL PRIVILEGES ON *.* TO 'hgh'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

SELECT CONCAT('用户 hgh 已创建，密码: hgh123456') AS result;

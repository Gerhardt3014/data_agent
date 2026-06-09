-- ============================================================
-- 学生信息数据库 - 创建与样例数据
-- 执行方式:
--   1. 先创建 hgh 用户:  sudo mysql < create_user.sql
--   2. 再创建数据库:     mysql -u hgh -p < setup_student_db.sql
-- ============================================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS student_db
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE student_db;

-- ======================== 班级表 ========================
DROP TABLE IF EXISTS `class`;
CREATE TABLE `class` (
    `class_id`     INT           NOT NULL AUTO_INCREMENT COMMENT '班级ID',
    `class_name`   VARCHAR(50)   NOT NULL COMMENT '班级名称',
    `grade`        VARCHAR(20)   NOT NULL COMMENT '年级',
    `department`   VARCHAR(50)   NOT NULL COMMENT '院系',
    `advisor`      VARCHAR(50)   NOT NULL COMMENT '班主任',
    `established`  DATE          NOT NULL COMMENT '建班日期',
    PRIMARY KEY (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='班级信息表';

-- ======================== 学生表 ========================
DROP TABLE IF EXISTS `student`;
CREATE TABLE `student` (
    `student_id`    VARCHAR(20)   NOT NULL COMMENT '学号',
    `name`          VARCHAR(50)   NOT NULL COMMENT '姓名',
    `gender`        ENUM('男','女') NOT NULL COMMENT '性别',
    `birth_date`    DATE          NOT NULL COMMENT '出生日期',
    `phone`         VARCHAR(20)   DEFAULT NULL COMMENT '手机号',
    `email`         VARCHAR(100)  DEFAULT NULL COMMENT '邮箱',
    `hometown`      VARCHAR(100)  DEFAULT NULL COMMENT '籍贯',
    `class_id`      INT           NOT NULL COMMENT '班级ID',
    `enrollment`    DATE          NOT NULL COMMENT '入学日期',
    `status`        ENUM('在读','休学','毕业','退学') NOT NULL DEFAULT '在读' COMMENT '状态',
    PRIMARY KEY (`student_id`),
    KEY `idx_class` (`class_id`),
    CONSTRAINT `fk_student_class` FOREIGN KEY (`class_id`) REFERENCES `class` (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生信息表';

-- ======================== 课程表 ========================
DROP TABLE IF EXISTS `course`;
CREATE TABLE `course` (
    `course_id`     VARCHAR(20)   NOT NULL COMMENT '课程编号',
    `course_name`   VARCHAR(100)  NOT NULL COMMENT '课程名称',
    `credit`        DECIMAL(3,1)  NOT NULL COMMENT '学分',
    `hours`         INT           NOT NULL COMMENT '学时',
    `category`      VARCHAR(30)   NOT NULL COMMENT '课程类别(必修/选修/公选)',
    `teacher`       VARCHAR(50)   NOT NULL COMMENT '授课教师',
    PRIMARY KEY (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='课程信息表';

-- ======================== 成绩表 ========================
DROP TABLE IF EXISTS `score`;
CREATE TABLE `score` (
    `id`            INT           NOT NULL AUTO_INCREMENT COMMENT '记录ID',
    `student_id`    VARCHAR(20)   NOT NULL COMMENT '学号',
    `course_id`     VARCHAR(20)   NOT NULL COMMENT '课程编号',
    `semester`      VARCHAR(20)   NOT NULL COMMENT '学期(如2025-2026-1)',
    `regular_score` DECIMAL(5,2)  DEFAULT NULL COMMENT '平时成绩',
    `midterm_score` DECIMAL(5,2)  DEFAULT NULL COMMENT '期中成绩',
    `final_score`   DECIMAL(5,2)  DEFAULT NULL COMMENT '期末成绩',
    `total_score`   DECIMAL(5,2)  DEFAULT NULL COMMENT '总评成绩',
    `gpa`           DECIMAL(3,2)  DEFAULT NULL COMMENT '绩点',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_student_course_sem` (`student_id`, `course_id`, `semester`),
    CONSTRAINT `fk_score_student` FOREIGN KEY (`student_id`) REFERENCES `student` (`student_id`),
    CONSTRAINT `fk_score_course`  FOREIGN KEY (`course_id`)  REFERENCES `course` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学生成绩表';


-- ======================== 插入样例数据 ========================

-- ---------- 班级 ----------
INSERT INTO `class` (`class_name`, `grade`, `department`, `advisor`, `established`) VALUES
('计算机科学1班', '2023级', '计算机学院', '张伟',   '2023-09-01'),
('计算机科学2班', '2023级', '计算机学院', '李芳',   '2023-09-01'),
('数据科学1班',   '2023级', '计算机学院', '王强',   '2023-09-01'),
('人工智能1班',   '2023级', '人工智能学院', '赵敏', '2023-09-01'),
('软件工程1班',   '2023级', '软件学院', '陈建华',   '2023-09-01');

-- ---------- 学生 (30人) ----------
INSERT INTO `student` (`student_id`, `name`, `gender`, `birth_date`, `phone`, `email`, `hometown`, `class_id`, `enrollment`, `status`) VALUES
-- 计算机科学1班 (8人)
('2023010101', '刘洋',   '男', '2004-03-15', '13800100001', 'liuyang@edu.cn',     '北京市海淀区',     1, '2023-09-01', '在读'),
('2023010102', '陈思雨', '女', '2004-07-22', '13800100002', 'chensiyu@edu.cn',    '上海市浦东新区',   1, '2023-09-01', '在读'),
('2023010103', '王浩然', '男', '2004-01-08', '13800100003', 'wanghaoran@edu.cn',  '广州市天河区',     1, '2023-09-01', '在读'),
('2023010104', '李佳琪', '女', '2004-11-30', '13800100004', 'lijiaqi@edu.cn',     '深圳市南山区',     1, '2023-09-01', '在读'),
('2023010105', '张子豪', '男', '2004-05-12', '13800100005', 'zhangzihao@edu.cn',  '成都市武侯区',     1, '2023-09-01', '在读'),
('2023010106', '赵雅婷', '女', '2004-09-03', '13800100006', 'zhaoyating@edu.cn',  '杭州市西湖区',     1, '2023-09-01', '在读'),
('2023010107', '周明轩', '男', '2004-02-28', '13800100007', 'zhoumingxuan@edu.cn','南京市鼓楼区',     1, '2023-09-01', '在读'),
('2023010108', '吴诗涵', '女', '2004-12-17', '13800100008', 'wushihan@edu.cn',    '武汉市洪山区',     1, '2023-09-01', '休学'),

-- 计算机科学2班 (7人)
('2023010201', '郑宇轩', '男', '2004-06-05', '13800100009', 'zhengyuxuan@edu.cn', '西安市雁塔区',   2, '2023-09-01', '在读'),
('2023010202', '孙梦瑶', '女', '2004-08-19', '13800100010', 'sunmengyao@edu.cn',  '重庆市渝北区',   2, '2023-09-01', '在读'),
('2023010203', '马天翔', '男', '2004-04-10', '13800100011', 'matianxiang@edu.cn', '长沙市岳麓区',   2, '2023-09-01', '在读'),
('2023010204', '黄诗琪', '女', '2004-10-25', '13800100012', 'huangshiqi@edu.cn',  '天津市南开区',   2, '2023-09-01', '在读'),
('2023010205', '林浩宇', '男', '2004-01-30', '13800100013', 'linhaoyu@edu.cn',    '福州市鼓楼区',   2, '2023-09-01', '在读'),
('2023010206', '何雨萱', '女', '2004-07-14', '13800100014', 'heyuxuan@edu.cn',    '合肥市蜀山区',   2, '2023-09-01', '在读'),
('2023010207', '高俊杰', '男', '2004-03-22', '13800100015', 'gaojunjie@edu.cn',   '郑州市金水区',   2, '2023-09-01', '在读'),

-- 数据科学1班 (6人)
('2023020101', '罗思远', '男', '2004-09-08', '13800100016', 'luosiyuan@edu.cn',   '成都市锦江区',   3, '2023-09-01', '在读'),
('2023020102', '谢雅文', '女', '2004-05-20', '13800100017', 'xieyawen@edu.cn',    '厦门市思明区',   3, '2023-09-01', '在读'),
('2023020103', '韩子轩', '男', '2004-11-02', '13800100018', 'hanzixuan@edu.cn',   '济南市历下区',   3, '2023-09-01', '在读'),
('2023020104', '唐欣怡', '女', '2004-02-14', '13800100019', 'tangxinyi@edu.cn',   '昆明市盘龙区',   3, '2023-09-01', '在读'),
('2023020105', '冯博文', '男', '2004-08-27', '13800100020', 'fengbowen@edu.cn',   '沈阳市和平区',   3, '2023-09-01', '在读'),
('2023020106', '董晓婷', '女', '2004-04-06', '13800100021', 'dongxiaoting@edu.cn','哈尔滨市南岗区', 3, '2023-09-01', '在读'),

-- 人工智能1班 (5人)
('2023030101', '潘嘉豪', '男', '2004-06-18', '13800100022', 'panjiahao@edu.cn',   '无锡市滨湖区',   4, '2023-09-01', '在读'),
('2023030102', '范诗颖', '女', '2004-12-09', '13800100023', 'fanshiying@edu.cn',  '宁波市鄞州区',   4, '2023-09-01', '在读'),
('2023030103', '魏子涵', '男', '2004-03-01', '13800100024', 'weizihan@edu.cn',    '青岛市市南区',   4, '2023-09-01', '在读'),
('2023030104', '姜雨桐', '女', '2004-10-11', '13800100025', 'jiangyutong@edu.cn', '大连市中山区',   4, '2023-09-01', '在读'),
('2023030105', '许志远', '男', '2004-07-25', '13800100026', 'xuzhiyuan@edu.cn',   '温州市鹿城区',   4, '2023-09-01', '毕业'),

-- 软件工程1班 (4人)
('2023040101', '叶欣然', '女', '2004-01-19', '13800100027', 'yexinran@edu.cn',    '东莞市南城区',   5, '2023-09-01', '在读'),
('2023040102', '邓浩然', '男', '2004-09-30', '13800100028', 'denghaoran@edu.cn',  '佛山市禅城区',   5, '2023-09-01', '在读'),
('2023040103', '曹思琪', '女', '2004-05-07', '13800100029', 'caosiqi@edu.cn',     '苏州市工业园区', 5, '2023-09-01', '在读'),
('2023040104', '彭宇轩', '男', '2004-11-23', '13800100030', 'pengyuxuan@edu.cn',  '南通市崇川区',   5, '2023-09-01', '退学');

-- ---------- 课程 (12门) ----------
INSERT INTO `course` (`course_id`, `course_name`, `credit`, `hours`, `category`, `teacher`) VALUES
('CS101', '程序设计基础',       4.0, 64, '必修', '刘教授'),
('CS102', '数据结构与算法',     4.0, 64, '必修', '张教授'),
('CS103', '计算机网络',         3.5, 56, '必修', '王教授'),
('CS201', '数据库原理',         3.5, 56, '必修', '李教授'),
('CS202', '操作系统',           4.0, 64, '必修', '赵教授'),
('CS203', '软件工程',           3.0, 48, '选修', '陈教授'),
('CS204', '人工智能导论',       3.0, 48, '选修', '孙教授'),
('CS205', '机器学习',           3.0, 48, '选修', '周教授'),
('CS206', '大数据技术',         3.0, 48, '选修', '吴教授'),
('GE101', '高等数学',           5.0, 80, '必修', '黄教授'),
('GE102', '线性代数',           3.0, 48, '必修', '马教授'),
('GE103', '大学英语',           2.0, 32, '公选', '何老师');

-- ---------- 成绩 (样例: 为计科1班8名学生生成部分成绩) ----------
INSERT INTO `score` (`student_id`, `course_id`, `semester`, `regular_score`, `midterm_score`, `final_score`, `total_score`, `gpa`) VALUES
-- 刘洋 - 学霸型
('2023010101', 'CS101', '2023-2024-1', 95.00, 92.00, 94.00, 93.50, 4.00),
('2023010101', 'GE101', '2023-2024-1', 90.00, 88.00, 91.00, 90.00, 4.00),
('2023010101', 'CS102', '2023-2024-2', 93.00, 95.00, 96.00, 95.00, 4.00),
('2023010101', 'CS103', '2023-2024-2', 88.00, 90.00, 92.00, 90.50, 4.00),
('2023010101', 'GE102', '2023-2024-2', 85.00, 87.00, 89.00, 87.50, 3.70),

-- 陈思雨 - 均衡型
('2023010102', 'CS101', '2023-2024-1', 88.00, 85.00, 87.00, 86.50, 3.70),
('2023010102', 'GE101', '2023-2024-1', 82.00, 79.00, 83.00, 81.50, 3.30),
('2023010102', 'CS102', '2023-2024-2', 86.00, 88.00, 85.00, 86.00, 3.70),
('2023010102', 'CS103', '2023-2024-2', 90.00, 87.00, 89.00, 88.50, 3.70),

-- 王浩然 - 偏科型（编程强，数学弱）
('2023010103', 'CS101', '2023-2024-1', 92.00, 95.00, 93.00, 93.50, 4.00),
('2023010103', 'GE101', '2023-2024-1', 65.00, 58.00, 62.00, 61.50, 1.50),
('2023010103', 'CS102', '2023-2024-2', 89.00, 91.00, 90.00, 90.00, 4.00),
('2023010103', 'GE102', '2023-2024-2', 60.00, 55.00, 58.00, 57.50, 1.00),

-- 李佳琪
('2023010104', 'CS101', '2023-2024-1', 78.00, 82.00, 80.00, 80.00, 3.00),
('2023010104', 'GE101', '2023-2024-1', 85.00, 83.00, 86.00, 84.50, 3.70),
('2023010104', 'CS102', '2023-2024-2', 75.00, 70.00, 73.00, 72.50, 2.30),
('2023010104', 'CS201', '2024-2025-1', 88.00, 85.00, 87.00, 86.50, 3.70),

-- 张子豪
('2023010105', 'CS101', '2023-2024-1', 70.00, 65.00, 68.00, 67.50, 2.00),
('2023010105', 'GE101', '2023-2024-1', 72.00, 75.00, 70.00, 72.00, 2.30),
('2023010105', 'CS102', '2023-2024-2', 68.00, 62.00, 65.00, 65.00, 1.50),
('2023010105', 'GE102', '2023-2024-2', 78.00, 80.00, 76.00, 77.50, 2.70),

-- 赵雅婷
('2023010106', 'CS101', '2023-2024-1', 91.00, 89.00, 93.00, 91.00, 4.00),
('2023010106', 'GE101', '2023-2024-1', 87.00, 90.00, 88.00, 88.50, 3.70),
('2023010106', 'CS102', '2023-2024-2', 94.00, 92.00, 95.00, 93.50, 4.00),
('2023010106', 'CS103', '2023-2024-2', 86.00, 84.00, 88.00, 86.00, 3.70),
('2023010106', 'GE103', '2023-2024-2', 90.00, 92.00, 88.00, 89.50, 3.70),

-- 周明轩
('2023010107', 'CS101', '2023-2024-1', 55.00, 50.00, 48.00, 50.50, 0.00),
('2023010107', 'GE101', '2023-2024-1', 62.00, 58.00, 60.00, 59.50, 1.00),
('2023010107', 'CS102', '2023-2024-2', 52.00, 45.00, 50.00, 48.50, 0.00),
('2023010107', 'GE102', '2023-2024-2', 60.00, 63.00, 58.00, 60.00, 1.00),

-- 吴诗涵（休学，成绩较少）
('2023010108', 'CS101', '2023-2024-1', 80.00, 76.00, 78.00, 78.00, 2.70),
('2023010108', 'GE101', '2023-2024-1', 73.00, 70.00, 75.00, 72.50, 2.30);

-- ======================== 有用的查询视图 ========================

-- 学生成绩总览视图
CREATE OR REPLACE VIEW v_student_score AS
SELECT
    s.student_id,
    s.name,
    c.class_name,
    co.course_name,
    sc.semester,
    sc.total_score,
    sc.gpa
FROM score sc
JOIN student s ON s.student_id = sc.student_id
JOIN class c   ON c.class_id = s.class_id
JOIN course co ON co.course_id = sc.course_id
ORDER BY s.student_id, sc.semester;

-- 学生 GPA 汇总视图
CREATE OR REPLACE VIEW v_student_gpa AS
SELECT
    s.student_id,
    s.name,
    c.class_name,
    COUNT(sc.id) AS course_count,
    ROUND(AVG(sc.gpa), 2) AS avg_gpa,
    ROUND(AVG(sc.total_score), 2) AS avg_score,
    MAX(sc.total_score) AS max_score,
    MIN(sc.total_score) AS min_score
FROM student s
JOIN class c   ON c.class_id = s.class_id
LEFT JOIN score sc ON sc.student_id = s.student_id
GROUP BY s.student_id, s.name, c.class_name
ORDER BY avg_gpa DESC;

-- ======================== 验证 ========================
SELECT '===== 数据统计 =====' AS '';
SELECT CONCAT('班级: ', COUNT(*), ' 个') AS summary FROM class;
SELECT CONCAT('学生: ', COUNT(*), ' 人') AS summary FROM student;
SELECT CONCAT('课程: ', COUNT(*), ' 门') AS summary FROM course;
SELECT CONCAT('成绩: ', COUNT(*), ' 条') AS summary FROM score;

SELECT '===== 学生 GPA 排名 =====' AS '';
SELECT * FROM v_student_gpa;

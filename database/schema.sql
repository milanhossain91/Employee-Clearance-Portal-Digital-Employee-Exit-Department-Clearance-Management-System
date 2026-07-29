-- =====================================================================
-- ACI Group — HR Clearance Portal
-- MySQL 8.x schema
--
-- Entities derived from the app:
--   Login page            -> users
--   Clearance Entry       -> businesses, employees, form_types, clearances
--   Add Form Type         -> departments, form_type_departments
--   Clearance Update      -> clearance_departments
--   Clearance View        -> vw_clearance_register (summary view)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS aci_clearance_portal
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE aci_clearance_portal;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS clearance_departments;
DROP TABLE IF EXISTS clearances;
DROP TABLE IF EXISTS form_type_departments;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS form_types;
DROP TABLE IF EXISTS businesses;
DROP VIEW IF EXISTS vw_clearance_register;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- users — portal logins (Staff ID + password only, no self-registration)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id        INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  staff_id       VARCHAR(20)      NOT NULL,
  full_name      VARCHAR(100)     NOT NULL,
  password_hash  VARCHAR(255)     NOT NULL,            -- bcrypt/argon2 hash
  role           ENUM('HR_ADMIN','DEPT_OFFICER','VIEWER') NOT NULL DEFAULT 'VIEWER',
  is_active      TINYINT(1)       NOT NULL DEFAULT 1,
  last_login_at  DATETIME         NULL,
  created_at     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_staff_id (staff_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- businesses — ACI business units (dropdown on Clearance Entry)
-- ---------------------------------------------------------------------
CREATE TABLE businesses (
  business_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name         VARCHAR(100)  NOT NULL,
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (business_id),
  UNIQUE KEY uq_businesses_name (name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- employees — staff master (looked up by Staff ID on Clearance Entry)
-- ---------------------------------------------------------------------
CREATE TABLE employees (
  employee_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  staff_id      VARCHAR(20)   NOT NULL,
  full_name     VARCHAR(100)  NOT NULL,
  designation   VARCHAR(100)  NULL,
  joining_date  DATE          NULL,
  business_id   INT UNSIGNED  NOT NULL,
  is_active     TINYINT(1)    NOT NULL DEFAULT 1,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (employee_id),
  UNIQUE KEY uq_employees_staff_id (staff_id),
  KEY ix_employees_business (business_id),
  CONSTRAINT fk_employees_business
    FOREIGN KEY (business_id) REFERENCES businesses (business_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- form_types — clearance form templates (Office employee, Field Force…)
-- ---------------------------------------------------------------------
CREATE TABLE form_types (
  form_type_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100)  NOT NULL,
  is_active     TINYINT(1)    NOT NULL DEFAULT 1,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (form_type_id),
  UNIQUE KEY uq_form_types_name (name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- departments — clearing departments (Corporate Admin, People Team…)
-- ---------------------------------------------------------------------
CREATE TABLE departments (
  department_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name           VARCHAR(100)  NOT NULL,
  is_active      TINYINT(1)    NOT NULL DEFAULT 1,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (department_id),
  UNIQUE KEY uq_departments_name (name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- form_type_departments — Add Form Type config:
-- which departments a form type requires, mandatory vs optional
-- ---------------------------------------------------------------------
CREATE TABLE form_type_departments (
  form_type_department_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  form_type_id             INT UNSIGNED  NOT NULL,
  department_id            INT UNSIGNED  NOT NULL,
  is_mandatory             TINYINT(1)    NOT NULL DEFAULT 0,
  sort_order               SMALLINT      NOT NULL DEFAULT 0,
  PRIMARY KEY (form_type_department_id),
  UNIQUE KEY uq_ftd_form_dept (form_type_id, department_id),
  KEY ix_ftd_department (department_id),
  CONSTRAINT fk_ftd_form_type
    FOREIGN KEY (form_type_id) REFERENCES form_types (form_type_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_ftd_department
    FOREIGN KEY (department_id) REFERENCES departments (department_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- clearances — one exit-clearance case per resignation (Clearance Entry)
-- ---------------------------------------------------------------------
CREATE TABLE clearances (
  clearance_id              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  employee_id               INT UNSIGNED  NOT NULL,
  business_id               INT UNSIGNED  NOT NULL,   -- snapshot at entry time
  form_type_id              INT UNSIGNED  NOT NULL,
  resign_date               DATE          NOT NULL,
  hrs_receiving_date        DATE          NOT NULL,
  online_submission_date    DATE          NULL,
  status                    ENUM('PENDING','CLEARED','RETURNED')
                                          NOT NULL DEFAULT 'PENDING',
  pending_at_department_id  INT UNSIGNED  NULL,       -- next dept awaiting action
  created_by                INT UNSIGNED  NOT NULL,
  created_at                DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at                DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (clearance_id),
  KEY ix_clearances_employee (employee_id),
  KEY ix_clearances_business (business_id),
  KEY ix_clearances_status (status),
  KEY ix_clearances_pending_at (pending_at_department_id),
  CONSTRAINT fk_clearances_employee
    FOREIGN KEY (employee_id) REFERENCES employees (employee_id),
  CONSTRAINT fk_clearances_business
    FOREIGN KEY (business_id) REFERENCES businesses (business_id),
  CONSTRAINT fk_clearances_form_type
    FOREIGN KEY (form_type_id) REFERENCES form_types (form_type_id),
  CONSTRAINT fk_clearances_pending_dept
    FOREIGN KEY (pending_at_department_id) REFERENCES departments (department_id),
  CONSTRAINT fk_clearances_created_by
    FOREIGN KEY (created_by) REFERENCES users (user_id),
  CONSTRAINT ck_clearances_dates
    CHECK (hrs_receiving_date >= resign_date)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- clearance_departments — per-department progress of one clearance
-- (rows are snapshotted from form_type_departments when the clearance
--  is created, so later config edits never change open cases)
-- ---------------------------------------------------------------------
CREATE TABLE clearance_departments (
  clearance_department_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  clearance_id             INT UNSIGNED  NOT NULL,
  department_id            INT UNSIGNED  NOT NULL,
  is_mandatory             TINYINT(1)    NOT NULL DEFAULT 0,
  submission_date          DATE          NULL,
  received_date            DATE          NULL,
  is_returned              TINYINT(1)    NOT NULL DEFAULT 0,
  remarks                  VARCHAR(255)  NULL,
  updated_by               INT UNSIGNED  NULL,
  updated_at               DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                         ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (clearance_department_id),
  UNIQUE KEY uq_cd_clearance_dept (clearance_id, department_id),
  KEY ix_cd_department (department_id),
  CONSTRAINT fk_cd_clearance
    FOREIGN KEY (clearance_id) REFERENCES clearances (clearance_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_cd_department
    FOREIGN KEY (department_id) REFERENCES departments (department_id),
  CONSTRAINT fk_cd_updated_by
    FOREIGN KEY (updated_by) REFERENCES users (user_id),
  CONSTRAINT ck_cd_received_after_submission
    CHECK (received_date IS NULL OR submission_date IS NOT NULL)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- vw_clearance_register — flat register feeding the Clearance View page
-- (one row per clearance × department; the app pivots per department)
-- ---------------------------------------------------------------------
CREATE VIEW vw_clearance_register AS
SELECT
  c.clearance_id,
  b.name                    AS business,
  e.staff_id,
  e.full_name               AS staff_name,
  c.resign_date,
  c.online_submission_date,
  c.status,
  pd.name                   AS pending_at,
  ft.name                   AS form_type,
  d.name                    AS department,
  cd.is_mandatory,
  cd.submission_date        AS dept_submission_date,
  cd.received_date          AS dept_received_date,
  cd.is_returned            AS dept_is_returned
FROM clearances c
JOIN employees e              ON e.employee_id = c.employee_id
JOIN businesses b             ON b.business_id = c.business_id
JOIN form_types ft            ON ft.form_type_id = c.form_type_id
LEFT JOIN departments pd      ON pd.department_id = c.pending_at_department_id
JOIN clearance_departments cd ON cd.clearance_id = c.clearance_id
JOIN departments d            ON d.department_id = cd.department_id;

-- ---------------------------------------------------------------------
-- Status automation:
-- after any department row changes, recompute the parent clearance —
--   any returned row            -> RETURNED
--   all mandatory rows received -> CLEARED
--   otherwise                   -> PENDING, pending_at = first mandatory
--                                  department not yet received
-- ---------------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_cd_after_update
AFTER UPDATE ON clearance_departments
FOR EACH ROW
BEGIN
  DECLARE v_returned INT;
  DECLARE v_open_mandatory INT;
  DECLARE v_pending_dept INT UNSIGNED;

  SELECT COUNT(*) INTO v_returned
  FROM clearance_departments
  WHERE clearance_id = NEW.clearance_id AND is_returned = 1;

  SELECT COUNT(*) INTO v_open_mandatory
  FROM clearance_departments
  WHERE clearance_id = NEW.clearance_id
    AND is_mandatory = 1
    AND received_date IS NULL;

  SELECT department_id INTO v_pending_dept
  FROM clearance_departments
  WHERE clearance_id = NEW.clearance_id
    AND is_mandatory = 1
    AND received_date IS NULL
  ORDER BY clearance_department_id
  LIMIT 1;

  UPDATE clearances
  SET
    status = CASE
      WHEN v_returned > 0 THEN 'RETURNED'
      WHEN v_open_mandatory = 0 THEN 'CLEARED'
      ELSE 'PENDING'
    END,
    pending_at_department_id = CASE
      WHEN v_returned > 0 OR v_open_mandatory = 0 THEN NULL
      ELSE v_pending_dept
    END
  WHERE clearance_id = NEW.clearance_id;
END //

-- ---------------------------------------------------------------------
-- sp_create_clearance — creates a clearance and snapshots the form
-- type's department list into clearance_departments in one transaction
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_create_clearance (
  IN p_staff_id            VARCHAR(20),
  IN p_form_type_id        INT UNSIGNED,
  IN p_resign_date         DATE,
  IN p_hrs_receiving_date  DATE,
  IN p_created_by          INT UNSIGNED
)
BEGIN
  DECLARE v_employee_id INT UNSIGNED;
  DECLARE v_business_id INT UNSIGNED;
  DECLARE v_clearance_id INT UNSIGNED;

  SELECT employee_id, business_id INTO v_employee_id, v_business_id
  FROM employees
  WHERE staff_id = p_staff_id AND is_active = 1;

  IF v_employee_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown or inactive Staff ID';
  END IF;

  START TRANSACTION;

  INSERT INTO clearances
    (employee_id, business_id, form_type_id, resign_date,
     hrs_receiving_date, created_by)
  VALUES
    (v_employee_id, v_business_id, p_form_type_id, p_resign_date,
     p_hrs_receiving_date, p_created_by);

  SET v_clearance_id = LAST_INSERT_ID();

  INSERT INTO clearance_departments (clearance_id, department_id, is_mandatory)
  SELECT v_clearance_id, department_id, is_mandatory
  FROM form_type_departments
  WHERE form_type_id = p_form_type_id
  ORDER BY sort_order, form_type_department_id;

  UPDATE clearances
  SET pending_at_department_id = (
    SELECT department_id
    FROM clearance_departments
    WHERE clearance_id = v_clearance_id AND is_mandatory = 1
    ORDER BY clearance_department_id
    LIMIT 1
  )
  WHERE clearance_id = v_clearance_id;

  COMMIT;

  SELECT v_clearance_id AS clearance_id;
END //

DELIMITER ;

-- =====================================================================
-- Seed data (matches the app's current dummy data)
-- =====================================================================

INSERT INTO businesses (name) VALUES
  ('ACI Limited'),
  ('ACI Agribusiness'),
  ('ACI Pharmaceuticals'),
  ('ACI Consumer Brands'),
  ('ACI Logistics'),
  ('ACI Motors'),
  ('ACI HealthCare');

INSERT INTO departments (name) VALUES
  ('Corporate Admin'),
  ('People Team'),
  ('MIS'),
  ('Marketing'),
  ('IT'),
  ('Transport'),
  ('Distribution'),
  ('Finance (NL I)'),
  ('Finance (NL II)'),
  ('Supply Chain'),
  ('Coordination Officer'),
  ('Safety'),
  ('Plant Admin');

INSERT INTO form_types (name) VALUES
  ('Office employee'),
  ('Field Force'),
  ('Factory Worker');

-- Office employee: mandatory + optional department config
INSERT INTO form_type_departments (form_type_id, department_id, is_mandatory, sort_order)
SELECT ft.form_type_id, d.department_id, x.is_mandatory, x.sort_order
FROM (
  SELECT 'Office employee' AS ft, 'Corporate Admin'      AS dept, 1 AS is_mandatory, 1 AS sort_order UNION ALL
  SELECT 'Office employee', 'People Team',          1, 2 UNION ALL
  SELECT 'Office employee', 'MIS',                  1, 3 UNION ALL
  SELECT 'Office employee', 'Finance (NL I)',       1, 4 UNION ALL
  SELECT 'Office employee', 'Finance (NL II)',      1, 5 UNION ALL
  SELECT 'Office employee', 'Supply Chain',         0, 6 UNION ALL
  SELECT 'Office employee', 'Coordination Officer', 0, 7 UNION ALL
  SELECT 'Field Force',     'Corporate Admin',      1, 1 UNION ALL
  SELECT 'Field Force',     'People Team',          1, 2 UNION ALL
  SELECT 'Field Force',     'Transport',            1, 3 UNION ALL
  SELECT 'Field Force',     'Distribution',         1, 4 UNION ALL
  SELECT 'Field Force',     'Marketing',            0, 5 UNION ALL
  SELECT 'Field Force',     'MIS',                  0, 6 UNION ALL
  SELECT 'Factory Worker',  'Corporate Admin',      1, 1 UNION ALL
  SELECT 'Factory Worker',  'People Team',          1, 2 UNION ALL
  SELECT 'Factory Worker',  'Safety',               1, 3 UNION ALL
  SELECT 'Factory Worker',  'Plant Admin',          1, 4 UNION ALL
  SELECT 'Factory Worker',  'Transport',            0, 5
) x
JOIN form_types ft ON ft.name = x.ft
JOIN departments d ON d.name = x.dept;

-- Portal user (password hash is a placeholder — generate with bcrypt in the app)
INSERT INTO users (staff_id, full_name, password_hash, role) VALUES
  ('ACI-000001', 'Md. Ariful Haque', '$2b$12$REPLACE_WITH_REAL_BCRYPT_HASH', 'HR_ADMIN');

INSERT INTO employees (staff_id, full_name, designation, joining_date, business_id)
SELECT x.staff_id, x.full_name, x.designation, x.joining_date, b.business_id
FROM (
  SELECT 'ACI-001234' AS staff_id, 'Md. Rafiqul Islam' AS full_name, 'Manager'          AS designation, DATE '2012-08-19' AS joining_date, 'ACI Limited'         AS business UNION ALL
  SELECT 'ACI-002891', 'Farhana Akter',   'Senior Officer',   DATE '2015-03-02', 'ACI Agribusiness'    UNION ALL
  SELECT 'ACI-003456', 'Karim Hossain',   'Executive',        DATE '2018-11-25', 'ACI Pharmaceuticals' UNION ALL
  SELECT 'ACI-004112', 'Nadia Rahman',    'Officer',          DATE '2019-06-10', 'ACI Consumer Brands' UNION ALL
  SELECT 'ACI-005778', 'Rezaul Karim',    'Senior Executive', DATE '2014-01-14', 'ACI Logistics'       UNION ALL
  SELECT 'ACI-006204', 'Sharmin Sultana', 'Officer',          DATE '2020-09-01', 'ACI Motors'          UNION ALL
  SELECT '3665',       'Imran Hossain',   'Senior Executive', DATE '2010-05-12', 'ACI Consumer Brands' UNION ALL
  SELECT 'md',         'Tasnim Hossain',  'Officer',          DATE '2016-02-06', 'ACI Consumer Brands'
) x
JOIN businesses b ON b.name = x.business;

-- Sample clearance: Imran Hossain (3665), Office employee form
CALL sp_create_clearance('3665', 1, DATE '2024-09-17', DATE '2024-09-20', 1);

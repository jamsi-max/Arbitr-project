/* Курсовой проект "Арбитр". Это портал который позволяет физическим и юридическим лицам 
 * заключать безопасные сделки. 
 * 
 * Идея в следующем: заказчик и исполнитель заключают на площадке договор, после чего заказчик вносит деньги, 
 * а исполнитель обязуется в срок исполнить условия договора. В случае успешного исполнения стороны подтверждают 
 * отсуттсвие претензий друг к другу и исполнитель получает свои деньги спустя установленный срок(2 недели). 
 * Если возникают претензии по исполнению с помощью портала ситуация разрешается путём спора и предоставления 
 * докозательств.
*/ 

DROP DATABASE IF EXISTS arbitr;
CREATE DATABASE arbitr;
USE arbitr;

-- Пользователи
DROP TABLE IF EXISTS users;
CREATE TABLE users(
	id SERIAL PRIMARY KEY,
	email VARCHAR(150) UNIQUE,
	password_hash VARCHAR(150),
	phone VARCHAR(12) UNIQUE,
	created_at DATETIME DEFAULT NOW(),
	updated_at DATETIME DEFAULT NOW() ON UPDATE NOW(),
	INDEX (phone)
);

-- Профиль физических лиц
DROP TABLE IF EXISTS profiles_persons;
CREATE TABLE profiles_persons(
	person_id BIGINT(20) UNSIGNED NOT NULL,
	firstname VARCHAR(150),
	lastname VARCHAR(150),
	patname VARCHAR(150),
	birthday DATE,
	photo_id BIGINT(20) UNSIGNED NOT NULL,
	home_town VARCHAR(100),
	is_deleted BIT,
	FOREIGN KEY (person_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Профиль юридических лиц
DROP TABLE IF EXISTS profiles_company;
CREATE TABLE profiles_company(
	company_id BIGINT(20) UNSIGNED NOT NULL,
	company_name VARCHAR(255),
	inn VARCHAR(10),
	ogrn VARCHAR(13),
	first_name_dir VARCHAR(50),
	last_name_dir VARCHAR(50),
	pat_name_dir VARCHAR(50),
	photo_id BIGINT(20) UNSIGNED NOT NULL,
	home_town VARCHAR(100),
	is_deleted BIT,
	INDEX (inn),
	FOREIGN KEY (company_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION,
	FOREIGN KEY (photo_id) REFERENCES user_photos(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Таблица фотографий
DORP TABLE IF EXISTS user_photos;
CREATE TABLE user_photos(
	id SERIAL PRIMARY KEY,
	link_id VARCHAR(255)
)


-- Таблица договоров
DROP TABLE IF EXISTS form_contracts;
CREATE TABLE form_contracts(
	id SERIAL PRIMARY KEY,
	client_id BIGINT(20) UNSIGNED NOT NULL,
	executor_id BIGINT(20) UNSIGNED NOT NULL,
	header_doc VARCHAR(255),
	contract TEXT,
	start_work DATETIME,
	end_work DATETIME,
	price DECIMAL,
	created_at DATETIME DEFAULT NOW(),
	updated_at DATETIME DEFAULT NOW() ON UPDATE NOW(),
	INDEX (header_doc),
	FOREIGN KEY (client_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION,
	FOREIGN KEY (executor_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Список договоров с указание статуса
DROP TABLE IF EXISTS list_contracts;
CREATE TABLE list_contracts(
	id_contracts BIGINT(20) UNSIGNED NOT NULL,
	status ENUM('created', 'signature', 'concluded', 'executed', 'dispute', 'dissolve'),
	FOREIGN KEY (id_contracts) REFERENCES form_contracts(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Таблица притензий
DROP TABLE IF EXISTS form_disputes;
CREATE TABLE form_disputes(
	id SERIAL PRIMARY KEY,
	applicant_id BIGINT(20) UNSIGNED NOT NULL,
	respondent_id BIGINT(20) UNSIGNED NOT NULL,
	contract_id BIGINT(20) UNSIGNED NOT NULL,
	dispute_text TEXT,
	dispute_price DECIMAL,
	created_at DATETIME DEFAULT NOW(),
	updated_at DATETIME DEFAULT NOW() ON UPDATE NOW(),
	FOREIGN KEY (applicant_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION,
	FOREIGN KEY (respondent_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION,
	FOREIGN KEY (contract_id) REFERENCES form_contracts(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Список претензий с указанием статуса
DROP TABLE IF EXISTS list_disputes;
CREATE TABLE list_disputes(
	id_dispute BIGINT(20) UNSIGNED NOT NULL,
	status ENUM('registered', 'considers', 'rejected', 'completed'),
	FOREIGN KEY (id_dispute) REFERENCES form_dispute(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- Репутация пользователей
DROP TABLE IF EXISTS reputation;
CREATE TABLE reputation(
	user_id BIGINT(20) UNSIGNED NOT NULL,
	reputation_status ENUM('beginner', 'approved', 'unreliable', 'reliable'),
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- группы заказчиков и исполнителей
DROP TABLE IF EXISTS group_list;
CREATE TABLE group_list(
	user_id BIGINT(20) UNSIGNED NOT NULL,
	user_group ENUM('customers', 'executor'),
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- сообщения
DROP TABLE IF EXISTS messages;
CREATE TABLE messages (
	id SERIAL PRIMARY KEY,
	from_user_id bigint(20) unsigned NOT NULL,
	to_user_id bigint(20) unsigned NOT NULL,
	body text,
	created_at DATETIME DEFAULT NOW(),
	INDEX(from_user_id, to_user_id),
	FOREIGN KEY (from_user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION,
 	FOREIGN KEY (to_user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE NO ACTION
);

-- ************************************************************************************************************
-- выводим общую сумму сделок по статусам контрактов(создан, подписан, исполнен, ведётся спор) и сумму каждого
-- контракта
SELECT
	fc.id,
	CONCAT(pp1.first_name,' ',pp1.last_name) AS client, 
	CONCAT(pp2.first_name,' ',pp2.last_name) AS executor, 
	fc.price AS price, 
	SUM(fc.price) OVER(PARTITION BY lc.status) AS sum_of_status, 
	lc.status AS status
FROM 
	form_contracts fc JOIN list_contracts lc ON fc.id = lc.id_contracts
	JOIN profiles_persons pp1 ON pp1.person_id = fc.client_id
	JOIN profiles_persons pp2 ON pp2.person_id = fc.executor_id;

-- сумма сделок по месяцам текущего года и общее число за этот год
SELECT
	DISTINCT CONCAT(YEAR(fc.created_at),'-',MONTH(fc.created_at)) AS month_data,
	SUM(fc.price) OVER(PARTITION BY MONTH(fc.created_at)) AS total_month,
	SUM(fc.price) OVER(PARTITION BY YEAR(fc.created_at)) AS total_year
FROM 
	form_contracts fc WHERE created_at > CONCAT(YEAR(NOW() - INTERVAL 1 YEAR),'-12-31');

-- сумма сделок по статусу контрактов в текущем году
SELECT 
	COUNT(*) as total_contracts, 
	SUM(price) as tottal_sum, 
	status FROM form_contracts fc JOIN list_contracts lc ON fc.id = lc.id_contracts 
WHERE created_at > CONCAT(YEAR(NOW() - INTERVAL 1 YEAR),'-12-31') 
GROUP BY status; 

-- выбираем определенного пользователя и считаем с кем он больше всего переписывался(делал по аналогии как на
-- лекциях только через табличные выражения cte) такая выборка может пригодиться для разрешения споров 
WITH dt AS (SELECT 
				from_user_id, 
				to_user_id,
				COUNT(from_user_id) as total
			FROM messages WHERE from_user_id = 39 OR to_user_id = 39 GROUP BY from_user_id, to_user_id ORDER BY total DESC) 
SELECT
	CONCAT(pp1.first_name,' ',pp1.last_name) AS `from`,
	CONCAT(pp2.first_name,' ',pp2.last_name) AS `to`,
	dt1.total+dt2.total AS total_message
FROM 
	dt dt1 JOIN dt dt2 ON dt1.to_user_id = dt2.from_user_id
	JOIN profiles_persons pp1 ON pp1.person_id = dt1.from_user_id
	JOIN profiles_persons pp2 ON pp2.person_id = dt1.to_user_id  limit 1;

-- выборка самых двух общительных пользователей(вроде бы самый простой по смыслу запрос однако дня два я поломал голову что бы его реализовать
-- иммено в таком виде!!! он мне нужен был для посмыслу использовать в спорах например! решил пока его несделаю курсовую сдавать не буду!) 
WITH dt AS (SELECT from_user_id, to_user_id, COUNT(from_user_id) AS total 
				FROM messages 
				GROUP BY from_user_id, to_user_id ORDER BY total DESC),
	 dt2 AS (SELECT dt3.from_user_id, dt3.to_user_id, dt3.total 
	 			FROM dt dt3 JOIN dt dt4 ON (dt3.from_user_id != dt4.to_user_id) AND (dt3.to_user_id != dt4.from_user_id)),
	 dt5 AS (SELECT dt6.from_user_id, dt6.to_user_id, dt6.total 
	 			FROM dt dt6 JOIN dt2 dt7 ON (dt6.from_user_id != dt7.from_user_id) and (dt6.to_user_id != dt7.to_user_id))
SELECT
	CONCAT(pp1.first_name,' ',pp1.last_name) AS `from`,
	CONCAT(pp2.first_name,' ',pp2.last_name) AS `to`,
	dt2.total+dt5.total AS total_message
FROM 
	dt2 
	JOIN dt5 ON dt2.from_user_id = dt5.to_user_id and dt2.to_user_id = dt5.from_user_id
	JOIN profiles_persons pp1 ON pp1.person_id = dt2.from_user_id
	JOIN profiles_persons pp2 ON pp2.person_id = dt5.from_user_id;

-- **********************************************************************************************
-- Пердставления:
-- 1. Выводит Id, имя фамилю отчество, дату рождения, почту, телефон пользователей зарегистрированных в текущем
--    году(год вычесляется автоматически представление работает от системного времени)

CREATE OR REPLACE VIEW new_persons(id, name, birthday, email, phone) AS SELECT 
	u.id, 
	CONCAT(pp.first_name,' ',pp.last_name,' ',pp.pat_name), 
	pp.birthday, u.email, 
	u.phone 
FROM 
	users u  
JOIN profiles_persons pp ON pp.person_id = u.id 
WHERE u.created_at > CONCAT(YEAR(NOW() - INTERVAL 1 YEAR),'-12-31');

-- **************************************************************************************
SELECT * FROM new_persons;

-- 2. Выводит имена заказчиков и исполнителей, id контрактов и дату их окнчания для всех завершенные 
--    в текущем году контрактов(год вычисляется автоматически от системного времени)
CREATE OR REPLACE VIEW contract_executor AS SELECT 
	fc.id as contractID, 
	CONCAT(pp.first_name,' ',pp.last_name) as client, 
	CONCAT(pp2.first_name,' ',pp2.last_name) as executor,
	fc.end_work as End_work,
	lc.status as status
FROM users u JOIN form_contracts fc ON u.id = fc.client_id 
JOIN list_contracts lc ON lc.id_contracts = fc.id
JOIN profiles_persons pp ON pp.person_id = fc.client_id
JOIN profiles_persons pp2 ON pp2.person_id = fc.executor_id
WHERE fc.created_at LIKE CONCAT(YEAR(NOW()),'%') AND lc.status = 'executed';
SELECT * FROM form_contracts as pc;
SELECT * FROM profiles_persons;
-- **********************************************************************************************************
SELECT * FROM contract_executor;

-- Триггеры:
-- 1. Тригер на таблицу form_contracts. При создании контракта автоматически добавляет запись в list_contracts
-- id контракта и статуст 'created' для последующей проверке и отправке исполнителю запроса на заключение контракта
DROP TRIGGER IF EXISTS form_contracts_insert;
DELIMITER //
CREATE TRIGGER form_contracts_insert AFTER INSERT ON form_contracts
FOR EACH ROW
BEGIN
	INSERT INTO list_contracts VALUE (NEW.id, 'created');
END//
DELIMITER ;

-- 2. Аналогичный тригир наvтаблицу споров. Добавляет в таблицу list_dispute запись с id спора и статусом 'registered'

DROP TRIGGER IF EXISTS form_dispute_insert;
DELIMITER //
CREATE TRIGGER form_dispute_insert AFTER INSERT ON form_disputes
FOR EACH ROW
BEGIN
	INSERT INTO list_disputes VALUE (NEW.id, 'registered');;
END//
DELIMITER ;

-- 3. Процедура удаляет все контракты со статусом "создан" более 6 месяцев назад по которым нет движения
--    соответственно подтверждения со стороны исполнителя.
DROP PROCEDURE IF EXISTS clear_contracts;
DELIMITER //
CREATE PROCEDURE clear_contracts() 
BEGIN
	DELETE FROM form_contracts 
	WHERE id in 
		(SELECT fc.id 
			FROM form_contracts fc JOIN list_contracts lc ON fc.id = lc.id_contracts 
				WHERE lc.status = 'created' 
				AND fc.created_at < CONCAT(YEAR(NOW()),'-',MONTH(NOW() - INTERVAL 6 MONTH),'-',DAY(NOW())));
END//
DELIMITER ;

CALL clear_contracts();

-- Функции:
-- функция last_month возвращает дату уменьшенную на число указанных месяцев от текущей даты
-- данная функция используется длы ваборок курсового проекта
DROP FUNCTION IF EXISTS last_month;
DELIMITER //
CREATE FUNCTION last_month(num INT)
RETURNS DATE NO SQL 
BEGIN
	RETURN CONCAT(YEAR(NOW()),'-',MONTH(NOW() - INTERVAL num MONTH),'-',DAY(NOW()));
END//
DELIMITER ;

select now(), last_month(7);


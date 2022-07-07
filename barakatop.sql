-- phpMyAdmin SQL Dump
-- version 5.0.4
-- https://www.phpmyadmin.net/
--
-- Хост: 127.0.0.1
-- Время создания: Дек 01 2021 г., 19:53
-- Версия сервера: 10.4.17-MariaDB
-- Версия PHP: 7.4.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- База данных: `barakatop`
--

DELIMITER $$
--
-- Процедуры
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_assign_order` (IN `pjurnal_id` INT, IN `ppoz` INT, IN `pfilial_id` INT, IN `pminvaqt` INT)  MODIFIES SQL DATA
Main:BEGIN
	
	DECLARE pok int DEFAULT 0;
	DECLARE pblock TINYINT DEFAULT 0;
	DECLARE pmashina_id int DEFAULT 0;
	DECLARE pmashina_jurnal int DEFAULT 0;
	DECLARE ptelefon varchar(30);
	DECLARE pfio varchar(100);
	DECLARE ptelefon2 varchar(30);
	DECLARE pfio2 varchar(100);
	DECLARE pdevice_id varchar(100);
	DECLARE pdevice_id2 varchar(100);
	DECLARE pactive_device_id varchar(100);

	IF pminvaqt<1 OR pminvaqt>120 THEN
		SET pok=-5; SELECT pok; LEAVE Main;
	END IF;

	SELECT m.block, m.id, j.id, m.fio, m.telefon, m.fio2, m.telefon2,
				m.device_id, m.device_id2, m.active_device
			INTO pblock, pmashina_id, pmashina_jurnal, pfio, ptelefon, pfio2, ptelefon2,
				pdevice_id, pdevice_id2, pactive_device_id
		FROM mashina AS m
		LEFT JOIN jurnal AS j ON j.mashina_id=m.id AND j.holat<=2
		WHERE m.filial_id=pfilial_id AND m.poz=ppoz AND m.uchirilgan<>1
		LIMIT 1;

	IF IFNULL(pmashina_id,0) = 0 THEN				SET pok=-1; SELECT pok; LEAVE Main;	
	ELSEIF IFNULL(pblock, 0) = 1 THEN					SET pok=-2; SELECT pok; LEAVE Main;	
	ELSEIF IFNULL(pmashina_jurnal,0) > 0 THEN					SET pok=-3; SELECT pok; LEAVE Main;		
	END IF;
	
	UPDATE jurnal SET holat=1, poz=ppoz,
			mashina_id=pmashina_id, filial_id=pfilial_id,
			vaqt2=NOW(), min_vaqt=pminvaqt
		WHERE holat=0 AND id=pjurnal_id;
    
			IF ROW_COUNT()>0 THEN 

		UPDATE mashina SET jurnal_id=pjurnal_id
			WHERE filial_id=pfilial_id AND poz=ppoz;
			
		IF pactive_device_id = pdevice_id2 THEN SET pfio = pfio2; SET ptelefon = ptelefon2; END IF;
		
		INSERT INTO sms (sana, jurnal_id, type, holat, fio, telefon) VALUES (NOW(), pjurnal_id, 1, 0, pfio, ptelefon);

		SET pok=1;

	ELSE
		
		SET pok=-4;

	END IF;
	
	SELECT pok;

END
;$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_book_order` (IN `porder_id` INT, IN `pdriver_id` INT, IN `pdate_accepted` DATETIME, IN `pcar_id` INT, IN `parrival_time` INT)  BEGIN
	
	DECLARE pbusy int DEFAULT 0;

	START TRANSACTION;

	SELECT id FROM orders 
		WHERE driver_id = pdriver_id 
					AND (status = 1 OR status = 2) LIMIT 1 INTO pbusy ;
	
	IF (pbusy > 0) THEN

		SELECT -pbusy AS result;

	ELSE

		UPDATE orders 
			SET status = 1, driver_id = pdriver_id, arrival_time = parrival_time, 
					date_accepted = pdate_accepted 
			WHERE id = porder_id AND status = 0;

		IF ROW_COUNT()>0 THEN

			UPDATE car SET current_order = porder_id WHERE id = pcar_id;

			INSERT INTO sms (type, status, date, order_id) VALUES(1, 0, NOW(), porder_id); 
		
			SELECT 1 AS result;
		
		ELSE

			SELECT 0 AS result;

		END IF;
			
	END IF;

	COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cancel_order` (IN `porder_id` INT, IN `pdriver_id` INT, IN `pcar_id` INT)  BEGIN

	DECLARE phone VARCHAR(20) DEFAULT "@";
	DECLARE pplatform int DEFAULT 0;
	DECLARE pstatus int DEFAULT 0;

	START TRANSACTION;
	
	
	SELECT platform, `status` FROM orders WHERE id = porder_id INTO pplatform, pstatus;

	UPDATE orders 
		SET status = 0, driver_id = NULL, date_accepted = null, 	
				date_started = NULL
		WHERE id = porder_id AND (status = 1 OR status = 2);
	
	
	IF ROW_COUNT()>0 THEN
		
		UPDATE car SET current_order = NULL WHERE id = pcar_id;
		INSERT INTO sms (type, status, date, order_id) VALUES (3, 0, NOW(), porder_id); 
		
		SELECT phone FROM orders WHERE id = porder_id INTO phone;

		IF pstatus <> 2 THEN

			UPDATE orders SET bonus = 0, sum_bonus = 0 WHERE id = porder_id;
			UPDATE client 
				SET counter1 = CASE WHEN counter1 > 0 THEN counter1 - 1 ELSE 0 END, 
						counter2 = counter3,
						counter2_date = counter3_date
				WHERE phone = phone AND pplatform=1;
		
		END IF;

		SELECT `value` FROM config WHERE name='BlockIfIgnore' LIMIT 1 INTO @BlockIfIgnore;
		
		IF @BlockIfIgnore > 0 AND pstatus < 2 THEN
			
			UPDATE car SET blocked = 2, blocked_until = DATE_ADD(NOW(),INTERVAL IFNULL(@BlockIfIgnore, 0) MINUTE)
				WHERE id = pcar_id;
		
		END IF;
	
		IF pstatus = 2 THEN

			UPDATE orders 
					SET status = 3, date_closed = NOW()
					WHERE id = porder_id;

		END IF;

		SELECT 1 AS result;

	ELSE

		SELECT 0 AS result;

	END IF;

	COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_check_for_bonus` (IN `pcondition` VARCHAR(200))  BEGIN

	DECLARE pbonus_id int;
	DECLARE pbonus_name varchar(50);
	DECLARE pbonus_condition text;
	DECLARE pbonus_value text;
  DECLARE done INT DEFAULT FALSE;
	DECLARE cur1 CURSOR FOR 
		SELECT `id`, `name`, `condition`, `value`
		FROM bonus WHERE active=1;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	OPEN cur1;

  read_loop: 
		LOOP
    FETCH cur1 INTO pbonus_id, pbonus_name, pbonus_condition, pbonus_value;
    IF done THEN
			LEAVE read_loop;
    END IF;
		
		IF (IFNULL(pbonus_value, "")<>"") THEN

			SET @pstmt = CONCAT("UPDATE orders SET ", pbonus_value, " WHERE ", pcondition);
			IF (IFNULL(pbonus_condition, "")<>"") THEN
				SET @pstmt=CONCAT(@pstmt, " AND (", pbonus_condition, ")");
			END IF;
			
			PREPARE stmt FROM @pstmt;
			EXECUTE stmt;
			DEALLOCATE PREPARE stmt; 

		END IF;

	END LOOP;

	CLOSE cur1;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_clear_orders` ()  BEGIN
	UPDATE orders SET driver_id=null, status=0, date_accepted=null, date_started=null,
	date_closed=null, bonus = 0, sum_bonus=0;
	TRUNCATE TABLE orders;
		UPDATE client SET counter1=0, counter2=0, counter2_date=null;
	TRUNCATE TABLE client;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_close_order` (IN `porder_id` INT, IN `pdriver_id` INT, IN `pdate_closed` DATETIME, IN `pcar_id` INT, IN `pdistance` FLOAT, IN `pdistance_out` FLOAT, IN `psum` FLOAT, IN `psum_services` FLOAT, IN `pservices` INT, IN `pstatus` INT)  BEGIN

	UPDATE orders 
		SET status = pstatus, driver_id = pdriver_id, date_closed = pdate_closed, 
				distance = pdistance, distance_out = pdistance_out, sum = psum, 
				sum_services = psum_services, services = pservices 
		WHERE id = porder_id;

	IF ROW_COUNT()>0 THEN

		UPDATE car SET current_order = null WHERE id = pcar_id;

		INSERT INTO sms (type, status, date, order_id) VALUES(4, 0, NOW(), porder_id); 

		SELECT 1 AS result;

	ELSE

		SELECT 0 AS result;

	END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_car` (IN `pcar_id` INT)  BEGIN

	DECLARE preg_num VARCHAR(20);

	SELECT reg_num FROM car WHERE id = pcar_id INTO preg_num;

	START TRANSACTION;

	UPDATE car 
		SET blocked = 1, blocked_until = NULL, 
				deleted = 1, deleted_date = NOW()
		WHERE id = pcar_id;
	
	IF ROW_COUNT()>0 THEN
		
		UPDATE driver SET code='', device_id='', token='' WHERE car_id=pcar_id;
		INSERT INTO car_blacklist (reg_num) VALUES (preg_num);
		SELECT 1 AS result;
	
	ELSE
		
		SELECT 0 AS result;

	END IF;
	
	COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_delete_order` (IN `porder_id` INT, IN `pbonus` INT, IN `pbonus2` INT)  BEGIN

	DECLARE pclient_id int;
	
		SELECT client_id INTO pclient_id FROM orders WHERE id=porder_id LIMIT 1;
		
	START TRANSACTION;

		UPDATE orders SET status=3, arrival_time=0, date_closed=now() WHERE id=porder_id AND status<3;
	
		IF ROW_COUNT()>0 THEN
	
			UPDATE car SET current_order=NULL WHERE current_order=porder_id;

				UPDATE client SET 
			counter1= CASE WHEN counter1 > 0 THEN counter1-1 ELSE 0 END, 
			counter2= CASE WHEN counter2 > 0 THEN counter2-1 ELSE 0 END 
			WHERE id=pclient_id;

						UPDATE orders SET 
			bonus = 0, sum_bonus = 0
			WHERE client_id=pclient_id AND status<3 AND id>porder_id;
		
		CALL sp_check_for_bonus(CONCAT("client_id=", pclient_id, " AND status<3 AND id>", porder_id));

		SELECT 1 AS result;
	
	ELSE

		SELECT 0 AS result;

	END IF;

	COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_insert_order` (IN `pid` INT, IN `pdate_created` DATETIME, IN `puser_id` INT, IN `pfrom` VARCHAR(100), IN `pto` VARCHAR(100), IN `pphone` VARCHAR(20), IN `pregion_id` INT, IN `porder_type` INT, IN `pplatform` INT, IN `psum_delivery` FLOAT, IN `platitude` DOUBLE, IN `plongitude` DOUBLE, IN `pcomments` VARCHAR(100), IN `pregion_id2` INT, IN `psum_offered` FLOAT)  BEGIN

	DECLARE pclient_id int;
	DECLARE pprev_phone VARCHAR(20) DEFAULT "@";
	DECLARE pcounter1 int DEFAULT 0;
	DECLARE pcounter2 int DEFAULT 0;
	DECLARE pcounter2_date date;
	DECLARE p1 int DEFAULT 0;
	DECLARE p2 int DEFAULT 0;
	DECLARE pstatus int DEFAULT 0;
	DECLARE ptemp int DEFAULT 0;
	
	START TRANSACTION;
		
	IF (IFNULL(platitude, 0) = 0) THEN 

		INSERT IGNORE INTO address (`name`, region_id) 
			VALUES (pfrom, pregion_id) ON DUPLICATE KEY UPDATE region_id = pregion_id;

	ELSE

		INSERT IGNORE INTO address (`name`, region_id, latitude, longitude) 
			VALUES (pfrom, pregion_id, platitude, plongitude) ON DUPLICATE KEY UPDATE region_id = pregion_id, latitude = platitude, longitude = plongitude;

	END IF;

	SELECT id
		FROM client 
		WHERE phone = pphone
		INTO pclient_id;
	
	IF (IFNULL(pclient_id, 0) = 0) THEN
		
		INSERT INTO client (`name`, phone, token, counter1, counter2, counter2_date) 
			VALUES ('', pphone, '', 0, 0, NULL);

		SET pclient_id = LAST_INSERT_ID();
		
	END IF;
		
	IF (pplatform = 1 OR pplatform = 2) THEN
		
		SELECT COUNT(*) FROM orders WHERE phone = pphone AND id <> pid AND (status < 3 OR status = 4) AND (platform = 1 OR platform = 2) INTO pcounter1;
		SET pcounter1 = pcounter1 + 1;
	
	END IF;

	IF (pid = 0) THEN

		IF porder_type = 4 THEN 
			SET pstatus = -2;
		END IF;
		IF pplatform = 1 AND porder_type<>4 THEN 
			SET pstatus = 0;
		END IF;

		INSERT INTO orders (client_id, `from`, `to`, phone, region_id, 
			comments, region_id2,
			order_type, platform, sum_delivery, latitude, longitude, 
			counter1, counter2, date_created, user_id, `status`, sum_offered, partner_id)
		VALUES (pclient_id, pfrom, pto, pphone, pregion_id, 
			pcomments, pregion_id2,
			porder_type, pplatform, psum_delivery, platitude, plongitude, 
			pcounter1, pcounter2, pdate_created, puser_id, pstatus, psum_offered, 1);
		
		SET pid = LAST_INSERT_ID();
	
	ELSE
		
		UPDATE orders 
			SET client_id = pclient_id, `from` = pfrom, `to` = pto, phone = pphone, 
					region_id = pregion_id, order_type = porder_type, platform = pplatform,
					comments = pcomments, region_id2 = pregion_id2,
					sum_delivery = psum_delivery, latitude = platitude, longitude = plongitude,
					counter1 = pcounter1, counter2 = pcounter2, sum_offered=psum_offered, partner_id = 1
		WHERE id = pid;
		
	END IF;
	
	

		

	
	

COMMIT;
	
SELECT pid AS id;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_start_order` (IN `porder_id` INT, IN `pdriver_id` INT, IN `pdate_started` DATETIME, IN `pcar_id` INT)  BEGIN
	
	DECLARE parrival_time1 int DEFAULT 0;
	DECLARE parrival_time2 int DEFAULT 0;

	START TRANSACTION;

	UPDATE orders 
		SET status=2, 
				driver_id=pdriver_id,
				date_started=pdate_started
		WHERE id=porder_id AND status=1;
	
	IF ROW_COUNT()>0 THEN
		
		SELECT IFNULL(arrival_time, 0), IFNULL(TIME_TO_SEC(TIMEDIFF(pdate_started, date_accepted)) / 60, 0)
			FROM orders WHERE id=porder_id LIMIT 1 INTO parrival_time1, parrival_time2;

		UPDATE car SET current_order=porder_id WHERE id=pcar_id;

		INSERT INTO sms (type, status, date, order_id) VALUES (2, 0, NOW(), porder_id);
	
				SELECT IFNULL(`value`, 0) FROM config WHERE name='BlockIfLate' LIMIT 1 INTO @BlockIfLate;
		
		IF (@BlockIfLate > 0 AND (parrival_time2 > parrival_time1 + @BlockIfLate) AND parrival_time1 > 0) THEN
			
			UPDATE car SET blocked = 2, blocked_until = DATE_ADD(NOW(), INTERVAL @BlockIfLate MINUTE)
				WHERE id = pcar_id;
		
		END IF;

		SELECT 1 AS result;

	ELSE

		SELECT 0 AS result;

	END IF;

	COMMIT;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_update_car_balances` (IN `pcar_id` INT)  BEGIN
	
	UPDATE car 
		SET balance = 
		(SELECT SUM(CASE WHEN reason = 2 THEN sum ELSE 0 END) -
						(SUM(CASE WHEN reason = 1 THEN sum ELSE 0 END) - 
            SUM(CASE WHEN reason = 3 THEN sum ELSE 0 END)) 
						FROM car_payment WHERE car_id = pcar_id AND DATE(date) <= CURDATE())
  WHERE id = pcar_id;
                  
END$$

--
-- Функции
--
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_formatted_time` (`ptime` DATETIME) RETURNS VARCHAR(50) CHARSET utf8 BEGIN

	DECLARE minutes int DEFAULT 0;
	DECLARE result VARCHAR(50) DEFAULT '';
	SELECT (TIMEDIFF(NOW() , ptime))/60 INTO minutes;
	IF minutes > 60 THEN
		SELECT CONCAT(TIME(ptime),' (>1с)') INTO result;
	ELSE
		SELECT CONCAT(TIME(ptime),' (>', minutes, 'м)') INTO result;
	END IF;
	
			
	RETURN result;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_get_autonum` (`pstart` INT) RETURNS INT(11) BEGIN


  DECLARE pnum INT DEFAULT 0;
  DECLARE done INT DEFAULT FALSE;
	DECLARE cur1 CURSOR FOR 
		SELECT num 
		FROM car
		WHERE deleted = 0 AND num >= pstart
		ORDER BY num;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	OPEN cur1;

  read_loop: LOOP

    FETCH cur1 INTO pnum;

    IF done THEN

			LEAVE read_loop;

    END IF;

		IF pstart = pnum THEN

			SET pstart = pstart + 1;

		END IF;

  END LOOP;

  CLOSE cur1;
	
	RETURN pstart;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_partner_closed` (`open_time` TIME, `close_time` TIME, `closed` INT) RETURNS BIT(1) BEGIN


	DECLARE now TIME DEFAULT TIME(NOW());

	IF (closed = 1) THEN
		RETURN 1;
	END IF;

	IF (now > open_time AND now < close_time AND close_time > open_time) THEN
		RETURN 0;
	END IF;

	IF (now > open_time AND now > close_time AND close_time < open_time) THEN
		RETURN 0;
	END IF;

	IF (now < open_time AND now < close_time AND close_time <= open_time) THEN
		RETURN 0;
	END IF;

	IF (open_time IS NULL OR close_time IS NULL ) THEN
		RETURN 0;
	END IF;
	
	RETURN 1;

END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `fn_time_format` (`pdate` DATETIME) RETURNS VARCHAR(50) CHARSET utf8 BEGIN

	DECLARE presult varchar(50) DEFAULT '';
	DECLARE pseconds int DEFAULT 0;
	DECLARE pdays int DEFAULT 0;

	
	SET presult = 
			CASE WHEN DATE(pdate)=CURDATE() THEN 
					DATE_FORMAT(pdate, '%H:%i:%S') 
			ELSE 
					DATE_FORMAT(pdate, '%d.%m.%Y %H:%i:%S') END;

	SET pseconds = TIMESTAMPDIFF(SECOND,pdate,NOW()) / 60;
	SET pdays = pseconds / 1440;

	SET presult = CONCAT(presult, 
		CASE 
				WHEN pseconds >= 1440 THEN CONCAT(' (>', pdays, 'к)')
				WHEN pseconds >= 60 THEN CONCAT(' (>', pseconds/60, 'с)')
				WHEN pseconds >= 1 THEN CONCAT(' (>', pseconds, 'м)')
				ELSE ' (>0м)'
		END);

	RETURN presult;

END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Структура таблицы `action`
--

CREATE TABLE `action` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `type` varchar(1) DEFAULT '',
  `group_id` int(11) DEFAULT 0,
  `priv` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `action`
--

INSERT INTO `action` (`id`, `name`, `type`, `group_id`, `priv`) VALUES
(100, 'Машиналар устида амаллар', 'G', 0, 0),
(101, 'Машина қўшиш/ўзгартириш', '', 100, 0),
(102, 'Машиналар рўйхатини кўриш', '', 100, 0),
(103, 'Машиналарни блоклаш ва очиш', '', 100, 0),
(104, 'Машиналарга ҳабар жўнатиш', '', 100, 0),
(105, 'Машиналар қора рўйхатига қўшиш/ўзгартириш', '', 100, 0),
(106, 'Машиналар тўловларини қўшиш/ўзгартириш', '', 100, 0),
(107, 'Машиналар тўловларини кўриш', '', 100, 0),
(200, 'Буюртмалар устида амаллар', 'G', 0, 0),
(201, 'Буюртма киритиш/ўзгартириш', '', 200, 0),
(202, 'Буюртмага машина бириктириш', '', 200, 0),
(203, 'Буюртмани вақтини очиш', '', 200, 0),
(204, 'Буюртмани ёпиш', '', 200, 0),
(205, 'Ёпилган буюртмани очиш', '', 200, 0),
(206, 'Буюртма вақтини янгилаш', '', 200, 0),
(207, 'Буюртмалар рўйхатини кўриш', '', 200, 0),
(208, 'Мижозга СМС жўнатиш', '', 200, 0),
(209, 'Ҳайдовчига СМС жўнатиш', '', 200, 0),
(300, 'Мижозлар устида амаллар', 'G', 0, 0),
(301, 'Мижоз қўшиш/ўзгартириш', '', 300, 0),
(302, 'Корпоратив мижоз қўшиш/ўзгартириш', '', 300, 0),
(303, 'Мижозлар рўйхатини кўриш', '', 300, 0),
(304, 'Мижозларга ҳабар жўнатиш', '', 300, 0),
(305, 'Мижозлар фикрига жавоб ёзиш', '', 300, 0),
(306, 'Мижозлар қора рўйхатига қўшиш/ўзгартириш', '', 300, 0),
(400, 'Ҳамкорлар устида амаллар', 'G', 0, 1),
(401, 'Ҳамкор қўшиш/ўзгартириш', '', 400, 1),
(402, 'Ҳамкорлар рўйхатини кўриш', '', 400, 1),
(500, 'Администратор амаллари', 'G', 0, 1),
(501, 'Тариф қўшиш/ўзгартириш', '', 500, 0),
(502, 'Акция қўшиш/ўзгартириш', '', 500, 0),
(503, 'Филиал қўшиш/ўзгартириш', '', 500, 0),
(504, 'Ҳудуд қўшиш/ўзгартириш', '', 500, 1),
(505, 'Кўча қўшиш/ўзгартириш', '', 500, 0),
(506, 'Диспетчер қўшиш/ўзгартириш', '', 500, 0),
(507, 'Дастурни созлаш', '', 500, 1),
(508, 'Маълумотларни архивлаш', '', 500, 1),
(509, 'Маълумотларни архивдан тиклаш', '', 500, 1),
(510, 'Маълумотларни ўчириш', '', 500, 1),
(511, 'Машина ва буюртмалар сонини кўриш', '', 500, 0),
(512, 'Рекламаларни ўзгартириш', '', 500, 1),
(600, 'Ҳисоботларни кўриш', 'G', 0, 0),
(601, 'Ҳисоботларни кўриш', '', 600, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `address`
--

CREATE TABLE `address` (
  `id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `region_id` int(11) DEFAULT NULL,
  `latitude` double DEFAULT 0,
  `longitude` double DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `address`
--

INSERT INTO `address` (`id`, `name`, `region_id`, `latitude`, `longitude`) VALUES
(1, 'BarakaTop', 1, 40.5422061, 70.9241242),
(1004, '|', 1, -1, 0),
(3189, ' ', 1, 40.530229, 70.936342),
(3753, 'BarakaTop дўкони', 1, 40.5445768, 70.9268932),
(3870, 'Озиқ-овқат маҳсулотлари', 1, 40.542925125919, 70.927741751075),
(4419, 'Озиқ-овқатлар', 1, 40.525157335214, 70.927839232609),
(4492, 'Китоблар', 3, 41.4114454, 69.4180779),
(4659, 'Симкарталар', 6, 40.531421592459, 70.947793191299),
(4779, 'Озик овкатлар', 1, 40.55780287832, 70.959086716175),
(4847, 'Электроника', 9, 40.539074090869, 70.973922700532),
(4854, 'Аёллар учун', 8, 40.5382188, 70.931131);

-- --------------------------------------------------------

--
-- Структура таблицы `ads`
--

CREATE TABLE `ads` (
  `id` int(11) NOT NULL,
  `image` varchar(300) COLLATE utf8_bin DEFAULT NULL,
  `description` varchar(300) COLLATE utf8_bin DEFAULT NULL,
  `url` varchar(300) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `ads`
--

INSERT INTO `ads` (`id`, `image`, `description`, `url`) VALUES
(3, '/images/ads_3_1608718260.png', NULL, 'https://t.me/barakatop_kokand'),
(4, '/images/ads_4.png', '', 'https://t.me/barakatop_kokand'),
(5, '', '', 'https://t.me/barakatop_kokand');

-- --------------------------------------------------------

--
-- Структура таблицы `bonus`
--

CREATE TABLE `bonus` (
  `id` int(11) NOT NULL,
  `active` bit(1) DEFAULT b'1',
  `name` varchar(50) DEFAULT NULL,
  `condition` text DEFAULT NULL,
  `value` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `bot`
--

CREATE TABLE `bot` (
  `id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT '',
  `status` int(11) DEFAULT 0,
  `order_type` int(11) DEFAULT 0,
  `address` varchar(100) DEFAULT NULL,
  `region_id` int(11) DEFAULT 0,
  `order_id` int(11) DEFAULT 0,
  `language` int(11) DEFAULT 0 COMMENT '1 - O''zbekcha, 2 - Russkiy, 3 - English',
  `zone_id` int(11) DEFAULT 0,
  `reg_code` int(11) DEFAULT 0,
  `client_id` int(11) DEFAULT 0,
  `chat_id` varchar(20) DEFAULT '0',
  `is_admin` int(11) DEFAULT 0,
  `store_id` int(11) DEFAULT 0,
  `group_id` int(11) DEFAULT 0,
  `product_id` int(11) DEFAULT 0,
  `data1` varchar(300) DEFAULT '',
  `data2` varchar(300) DEFAULT NULL,
  `data3` varchar(300) DEFAULT NULL,
  `data4` varchar(300) DEFAULT NULL,
  `message_id` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `bot`
--

INSERT INTO `bot` (`id`, `name`, `phone`, `status`, `order_type`, `address`, `region_id`, `order_id`, `language`, `zone_id`, `reg_code`, `client_id`, `chat_id`, `is_admin`, `store_id`, `group_id`, `product_id`, `data1`, `data2`, `data3`, `data4`, `message_id`) VALUES
(93, NULL, '', 103, 0, NULL, 0, 0, 0, 0, 0, 1, '982176601', 1, 1, 1191, 5, 'hbbh', '07:00:00-20:00:00', '50000', '', 843),
(145, NULL, '', 103, 0, NULL, 0, 0, 0, 0, 0, 1, '734885202', 1, 1, 1201, 2046, '', NULL, NULL, NULL, 0),
(147, NULL, '', 101, 0, NULL, 0, 0, 0, 0, 0, 0, '306887416', 0, 0, 0, 0, '', NULL, NULL, NULL, 0),
(154, NULL, '', 101, 0, NULL, 0, 0, 0, 0, 0, 0, '1503552', 0, 0, 0, 0, '', NULL, NULL, NULL, 0),
(155, NULL, '', 101, 0, NULL, 0, 0, 0, 0, 0, 0, '130672268', 0, 0, 0, 0, '', NULL, NULL, NULL, 0),
(157, NULL, '', 0, 0, NULL, 0, 0, 0, 0, 0, 1, '1412326894', 1, 1, 1225, 2009, '', NULL, NULL, NULL, 0),
(158, NULL, '', 101, 0, NULL, 0, 0, 0, 0, 0, 0, '930484543', 0, 0, 0, 0, '', NULL, NULL, NULL, 0),
(159, NULL, '', 101, 0, NULL, 0, 0, 0, 0, 0, 0, '805086778', 0, 0, 0, 0, '', NULL, NULL, NULL, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `bot_user`
--

CREATE TABLE `bot_user` (
  `id` int(11) NOT NULL,
  `phone` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `bot_user`
--

INSERT INTO `bot_user` (`id`, `phone`) VALUES
(1, '+998916848100'),
(2, '+998974164400'),
(3, '+998944445888');

-- --------------------------------------------------------

--
-- Структура таблицы `car`
--

CREATE TABLE `car` (
  `id` int(11) NOT NULL,
  `department_id` int(11) DEFAULT 0,
  `num` int(11) DEFAULT NULL,
  `reg_num` varchar(50) DEFAULT NULL,
  `color` varchar(50) DEFAULT NULL,
  `model` varchar(50) DEFAULT NULL,
  `license_num` varchar(50) DEFAULT NULL,
  `license_date` date DEFAULT NULL,
  `comments` varchar(400) DEFAULT NULL,
  `blocked` int(1) NOT NULL DEFAULT 0,
  `blocked_until` datetime DEFAULT NULL,
  `online` bit(1) NOT NULL DEFAULT b'0',
  `current_driver` int(11) DEFAULT NULL,
  `current_region` int(11) DEFAULT 0,
  `current_order` int(11) DEFAULT NULL,
  `book_region_time` datetime DEFAULT NULL,
  `deleted` bit(1) DEFAULT b'0',
  `deleted_date` datetime DEFAULT NULL,
  `created_date` datetime DEFAULT NULL,
  `order_types` varchar(100) DEFAULT '',
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `speed` double DEFAULT NULL,
  `balance` float DEFAULT 0,
  `payment_type_id` int(11) DEFAULT NULL,
  `payment_weekend` int(11) DEFAULT 0,
  `payment_info` varchar(300) DEFAULT NULL,
  `payment_discount` int(11) DEFAULT 0,
  `payment_expdate` datetime DEFAULT NULL,
  `payment_calc_time` date DEFAULT NULL,
  `order_count` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `car_blacklist`
--

CREATE TABLE `car_blacklist` (
  `id` int(11) NOT NULL,
  `reg_num` varchar(20) DEFAULT NULL,
  `comments` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `car_blacklist`
--

INSERT INTO `car_blacklist` (`id`, `reg_num`, `comments`) VALUES
(113, '40 884 TTG', NULL),
(114, '40 M 867 GA', NULL),
(115, '40 N 698 RA', NULL),
(116, '40 588 TTK', NULL),
(117, '40  B 440 BA', NULL),
(118, '40 348 TTF', NULL),
(119, '40 B 010 OA', NULL),
(120, '40 Y 616 JA', NULL),
(121, '40 482 TTJ', NULL),
(122, '40 292 TTF', NULL),
(123, '40 N 347 MA', NULL),
(124, '40 211 TTF', NULL),
(125, '40 772 TTA', NULL),
(126, '40 207 TTF', NULL),
(127, '40 470 TTJ', NULL),
(128, '40 025 TTJ', NULL),
(129, '260 TTD', NULL),
(130, '40 A 221 QA', NULL),
(131, '40 W 223 NA', NULL),
(132, '873', NULL),
(133, '40 196 TTG', NULL),
(134, '40 991 TTD', NULL),
(135, '40 M 456 PA', NULL),
(136, '40 293 TTF', NULL),
(137, '40 054 TTF', NULL),
(138, '40 N 027 MA', NULL),
(139, '493', NULL),
(140, '40 422 TTF', NULL),
(141, '40 603 TTK', NULL),
(142, '40 A 172  SA', NULL),
(143, '40 201 TTF', NULL),
(144, '399', NULL),
(145, '40 211 TTF', NULL),
(147, '40 905 TTA', NULL),
(148, '40 223 TTF', NULL),
(149, '40 N 890 LA', NULL),
(150, '40 A 172 SA', NULL),
(151, '40 349 TTF', NULL),
(152, '40 427 TTF', NULL),
(153, '40 423 TTF', NULL),
(154, '40 426 TTF', NULL),
(155, '605', NULL),
(156, '40 453 TTJ', NULL),
(157, '40 347 TTF', NULL),
(158, '40 427 TTF', NULL),
(159, '40 251 TTF', NULL),
(160, '667', NULL),
(161, '376', NULL),
(162, '438 TTG', NULL),
(163, '40 206 TTF', NULL),
(164, '40 123 TTA', NULL),
(165, '40 425 TTF', NULL),
(166, '40 021', NULL),
(167, '40 101 TTD', NULL),
(168, '01 100 AAA', NULL),
(169, '122ТТJ', NULL),
(171, '723', NULL),
(173, '781  TTK', NULL),
(174, '490 TTJ', NULL),
(175, '663 TTJ', NULL),
(176, '942 TTA', NULL),
(177, '194', NULL),
(178, '349', NULL),
(181, '108', NULL),
(183, '012', NULL),
(184, '566', NULL),
(185, '122', NULL),
(187, '122 ТТJ', NULL),
(188, '213', NULL),
(189, '213 ТТА', NULL),
(190, '213 ТТЕ', NULL),
(191, '012ТТС', NULL),
(192, '950', NULL),
(194, '40 Y 887 YA', NULL),
(195, '40 A 444 TF', NULL),
(196, '40 A 404 AA', NULL),
(197, '40 A 678 DA', NULL),
(199, '432', NULL),
(201, '795', NULL),
(204, '498', NULL),
(205, '642 TTJ', NULL),
(206, '629', NULL),
(207, '625 TTJ', NULL),
(208, '731 ТТК', NULL),
(209, '260TTD', NULL),
(210, '089 TTJ', NULL),
(211, '283', NULL),
(212, '893 TTF', NULL),
(215, '687 TTK', NULL),
(216, '249 TTJ', NULL),
(217, '755', NULL),
(218, '248  TTG', NULL),
(219, '870 TTK', NULL),
(220, '898 TTJ', NULL),
(221, '987 TTJ', NULL),
(223, '139 TTC', NULL),
(224, '623', NULL),
(225, '841 TTF', NULL),
(226, '654 TTJ', NULL),
(228, '942 TTJ', NULL),
(229, '863TTF', NULL),
(230, '091 TTJ', NULL),
(231, '734 TTK', NULL),
(232, '851  TTK', NULL),
(233, '228 TTF', NULL),
(234, '534 TTK', NULL),
(235, '406 TTF', NULL),
(236, '877', NULL),
(238, '477 TTF', NULL),
(239, '972 TTJ', NULL),
(240, '901 TTJ', NULL),
(241, '216TTF', NULL),
(242, '855', NULL),
(244, '931 TTF', NULL),
(245, '224', NULL),
(246, '896 TTE', NULL),
(250, '637 TTK', NULL),
(251, '856', NULL),
(252, '588', NULL),
(253, '459', NULL),
(254, '881', NULL),
(255, '943', NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `car_color`
--

CREATE TABLE `car_color` (
  `id` int(11) NOT NULL,
  `name` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `car_color`
--

INSERT INTO `car_color` (`id`, `name`) VALUES
(6, ''),
(347, 'CАРИК'),
(710, 'DELFIN'),
(677, 'DELFIN RANG'),
(2683, 'kAYMOK'),
(1842, 'kizil'),
(1942, 'kUK'),
(1923, 'mokri'),
(4550, 'Mokriy'),
(3028, 'Ok'),
(2, 'OQ'),
(4490, 'Qaymoq'),
(3494, 'QORA'),
(3049, 'SARIk'),
(1, 'SARIQ'),
(4511, 'Sariqq'),
(1897, 'Seriy'),
(5612, 'Sitalnoy'),
(4505, 'Ssariq'),
(3143, 'STALNOY'),
(153, 'ау'),
(1025, 'каймок'),
(148, 'кора'),
(6461, 'ОК'),
(136, 'САРИК'),
(304, 'СЕРЕ');

-- --------------------------------------------------------

--
-- Структура таблицы `car_message`
--

CREATE TABLE `car_message` (
  `id` int(11) NOT NULL,
  `date` datetime DEFAULT NULL,
  `text` varchar(256) DEFAULT NULL,
  `type` int(11) DEFAULT NULL COMMENT '0 - dispetcher>drivers; 1 - drivers SOS; 2 - drivers>dispetcher',
  `sender_id` int(11) DEFAULT NULL,
  `receiver_id` int(11) DEFAULT NULL,
  `department_id` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `car_message`
--

INSERT INTO `car_message` (`id`, `date`, `text`, `type`, `sender_id`, `receiver_id`, `department_id`) VALUES
(1861, '2019-07-13 01:33:54', 'test', 0, 17, 1, 0),
(1862, '2019-07-13 01:34:39', 'test', 0, 17, 1, 0),
(1863, '2019-07-13 01:35:54', 'test', 0, 17, 0, 0),
(1864, '2019-07-13 01:39:00', 'test', 0, 17, 1, 0),
(1865, '2019-07-13 01:40:55', 'salom test', 0, 17, 1, 0),
(1866, '2019-07-13 01:49:38', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 17, 0, 0),
(1867, '2019-07-13 01:53:32', 'шопирлар', 0, 17, 1, 0),
(1868, '2019-07-13 01:53:43', 'ШОПИРЛАР ҚАНИСИЗ', 0, 17, 1, 0),
(1869, '2019-07-13 01:53:58', '\"ШОПИРЛАР\" \'ee\'', 0, 17, 1, 0),
(1870, '2019-07-13 01:54:33', '\"ШИ\"\'fff\'', 0, 17, 1, 0),
(1871, '2019-07-13 01:54:56', 'OOO', 0, 17, 1, 0),
(1872, '2019-07-13 01:55:04', '\"ОО\"', 0, 17, 1, 0),
(1873, '2019-07-13 01:55:36', '\"SSS\"', 0, 17, 1, 0),
(1874, '2019-07-13 01:56:23', '\"ШШО', 0, 17, 1, 0),
(1875, '2019-07-13 01:56:44', 'Шои', 0, 17, 1, 0),
(1876, '2019-07-13 01:57:48', 'ШОИ', 0, 17, 1, 0),
(1877, '2019-07-13 01:58:24', 'шир', 0, 17, 1, 0),
(1878, '2019-07-13 02:01:35', 'ШҚҚҚ', 0, 17, 1, 0),
(1879, '2019-07-13 02:01:44', '\"СААА\"', 0, 17, 1, 0),
(1880, '2019-07-13 02:02:38', '\"ССС\"', 0, 17, 1, 0),
(1881, '2019-07-13 02:02:58', '\"САЛА\"', 0, 17, 1, 0),
(1882, '2019-07-13 02:04:26', '\"САЛА\"', 0, 17, 1, 0),
(1883, '2019-07-13 02:04:35', '999^\"САЛА\"', 0, 17, 0, 0),
(1884, '2019-07-13 02:04:50', '\"Саа', 0, 17, 1, 0),
(1885, '2019-07-13 02:05:33', 'САЛОМ', 0, 17, 1, 0),
(1886, '2019-07-13 03:12:43', 'test habar', 0, 17, 1, 0),
(1887, '2019-07-13 12:09:47', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 17, 0, 0),
(1888, '2019-07-13 12:11:12', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 17, 0, 0),
(1889, '2019-07-13 12:11:53', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 17, 0, 31),
(1890, '2019-07-14 08:56:30', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 43, 0, 0),
(1891, '2019-07-14 09:18:13', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 43, 0, 0),
(1892, '2019-07-14 09:18:21', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 43, 0, 0),
(1893, '2019-07-14 12:17:55', 'ЭРТАЛАБ 7 ЛАРДА НЕКСИЯ МОШИНАМИЗДА ЙУЛОВЧИМИЗИ НАРСАЛАРИ КОЛИБ КЕТИБДИ БИЛГАНЛАР  90 509 90 77 ГА ЁКИ ОФЕСГА ТЕЛ  ', 0, 43, 0, 0),
(1894, '2019-07-15 00:49:30', 'zayavkalani olila ', 0, 49, 0, 0),
(1895, '2019-07-15 16:13:39', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 17, 0, 0),
(1896, '2019-07-15 16:17:55', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 43, 0, 0),
(1897, '2019-07-15 16:19:21', 'ХУРМАТЛИ ШОПИРЛАР ЗАЯВКАЛАРГА ЮРИББЕРИЛАР ', 0, 43, 0, 0),
(1898, '2019-07-15 16:41:21', '7-ПОЛИКЛИНИКАГА ЮРИБ БЕРИЛАР', 0, 43, 0, 0),
(1899, '2019-07-16 06:20:14', '293 SHOPIRIMIZI  UTIRB QOLDI PEREKULITRI BORLA YORDAM QLILA ILTIMOSAKAN BUSTANOBOD 56  901513501 ', 0, 49, 0, 0),
(1900, '2019-07-16 06:20:54', '293 SHOPIRIMIZI  UTIRB QOLDI PEREKULITRI BORLA YORDAM QLILA ILTIMOSAKAN BUSTANOBOD 56  901513501 ', 0, 49, 0, 0),
(1901, '2019-07-16 08:59:29', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 43, 0, 0),
(1902, '2019-07-16 12:12:42', 'ЧОРСИДА ЧОРСИ МАРКЕТ ТОМОНДА РЕЙД', 0, 43, 0, 0),
(1903, '2019-07-16 13:19:36', 'ЧОРСИДА ЧОРСИ МАРКЕТ ТОМОНДА РЕЙД', 0, 43, 0, 0),
(1904, '2019-07-16 18:38:28', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1905, '2019-07-16 18:59:59', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1906, '2019-07-16 19:42:52', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1907, '2019-07-16 20:15:27', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1908, '2019-07-16 20:21:10', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1909, '2019-07-16 20:27:08', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1910, '2019-07-16 20:27:58', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1911, '2019-07-16 20:38:56', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1912, '2019-07-16 20:40:10', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1913, '2019-07-16 20:40:48', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1914, '2019-07-16 20:45:59', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1915, '2019-07-16 20:51:47', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1916, '2019-07-16 20:55:04', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1917, '2019-07-16 20:56:23', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1918, '2019-07-16 20:59:29', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1919, '2019-07-16 21:12:07', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1920, '2019-07-16 21:14:56', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1921, '2019-07-16 21:17:00', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1922, '2019-07-16 21:19:48', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(1923, '2019-07-17 00:42:13', 'test', 0, 17, 366, 0),
(1924, '2019-07-17 00:42:27', 'test', 0, 17, 366, 0),
(1925, '2019-07-17 00:58:14', 'test', 0, 17, 366, 0),
(1926, '2019-07-17 00:58:47', 'test', 0, 17, 366, 0),
(1927, '2019-07-17 04:10:27', 'касмантга юрворилар', 0, 45, 0, 0),
(1928, '2019-07-17 04:19:00', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 52, 0, 0),
(1929, '2019-07-17 04:20:17', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1930, '2019-07-17 04:26:45', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1931, '2019-07-17 04:28:47', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1932, '2019-07-17 04:29:55', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1933, '2019-07-17 04:34:06', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1934, '2019-07-17 04:35:25', 'ЮРИЛАР ШОПИРЛАР ЗАЯВКАЛАРГА', 0, 47, 0, 0),
(1935, '2019-07-17 04:38:17', 'GAZGAZGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1936, '2019-07-17 05:37:12', 'ШОПИРЛАР АВТОВАГЗАЛДА РЕТ БУЛЯПДИКАН', 0, 52, 0, 0),
(1937, '2019-07-17 07:55:13', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 43, 0, 0),
(1938, '2019-07-17 08:03:53', 'GORGAZGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1939, '2019-07-17 08:44:25', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1940, '2019-07-17 08:45:17', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1941, '2019-07-17 08:45:20', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1942, '2019-07-17 08:52:52', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1943, '2019-07-17 08:52:54', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1944, '2019-07-17 08:52:55', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1945, '2019-07-17 08:56:42', 'ПУТЁВКА ЛИЦЕНЗИЯГА РЕЙД БОШЛАНДИ ЧОРСИДА ', 0, 43, 0, 0),
(1946, '2019-07-17 09:15:53', 'ПУТЁВКА ЛИЦЕНЗИЯГА РЕЙД БОШЛАНДИ ЧОРСИДА ', 0, 43, 0, 0),
(1947, '2019-07-17 09:15:57', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 43, 0, 0),
(1948, '2019-07-17 09:18:36', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1949, '2019-07-17 09:18:39', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1950, '2019-07-17 09:56:13', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1951, '2019-07-17 09:56:16', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1952, '2019-07-17 10:00:08', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1953, '2019-07-17 10:00:11', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1954, '2019-07-17 10:01:06', 'XUDOYORXON 32 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1955, '2019-07-17 10:21:59', 'ЗАЯВКАЛАРГА ЮРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР', 0, 46, 0, 0),
(1956, '2019-07-17 10:22:05', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1957, '2019-07-17 10:38:45', 'ZELYONIYGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1958, '2019-07-17 12:06:26', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1959, '2019-07-17 12:06:28', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1960, '2019-07-17 12:24:22', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1961, '2019-07-17 12:24:25', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1962, '2019-07-17 12:39:46', 'БИР ЛАХЗАГА ЮРИБ БЕРИЛАР КЛИЕНТИМИЗ КУТИШЯПТИ', 0, 43, 0, 0),
(1963, '2019-07-17 13:07:34', 'T MALIK 6 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1964, '2019-07-17 13:27:12', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1965, '2019-07-17 13:27:14', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1966, '2019-07-17 13:29:47', 'IBN SINO 11/A GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1967, '2019-07-17 13:29:52', 'IBN SINO 11/A GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1968, '2019-07-17 13:33:16', 'IBN SINO 11/A GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1969, '2019-07-17 13:33:20', 'IBN SINO 11/A GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1970, '2019-07-17 14:30:53', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1971, '2019-07-17 14:30:59', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1972, '2019-07-17 14:33:42', 'MJK BALNITSAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1973, '2019-07-17 15:07:32', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1974, '2019-07-17 15:07:34', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1975, '2019-07-17 16:10:23', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1976, '2019-07-17 16:10:25', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1977, '2019-07-17 16:17:45', 'МЕБЕЛ ДАРВОЗАГА ЮРИБ БЕРИЛАР', 0, 43, 0, 0),
(1978, '2019-07-17 17:45:40', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1979, '2019-07-17 17:45:42', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1980, '2019-07-17 17:45:44', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(1981, '2019-07-17 17:59:46', 'CHORTOQ 23 GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1982, '2019-07-17 18:01:51', 'CHORTOQ 23 GA YURVORILAR ILTIMOS KLENT KUTIB QOLDILAR', 0, 46, 0, 0),
(1983, '2019-07-17 18:50:00', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(1984, '2019-07-17 18:48:22', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1985, '2019-07-17 18:50:08', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1986, '2019-07-17 19:01:03', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(1987, '2019-07-17 19:00:54', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1988, '2019-07-17 19:09:51', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(1989, '2019-07-17 19:17:41', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(1990, '2019-07-17 19:20:12', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1991, '2019-07-17 19:27:29', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1992, '2019-07-17 19:30:00', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1993, '2019-07-17 19:32:57', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(1994, '2019-07-17 19:31:00', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1995, '2019-07-17 19:34:31', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1996, '2019-07-17 19:35:24', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1997, '2019-07-17 19:36:11', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1998, '2019-07-17 19:38:19', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(1999, '2019-07-17 19:39:05', 'PLANGA ZAMIN', 0, 50, 0, 0),
(2000, '2019-07-17 19:41:53', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2001, '2019-07-17 19:39:12', 'PLANGA ZAMIN', 0, 50, 0, 0),
(2002, '2019-07-17 19:41:08', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2003, '2019-07-17 19:43:37', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2004, '2019-07-17 19:43:09', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2005, '2019-07-17 19:44:42', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2006, '2019-07-17 19:50:16', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2007, '2019-07-17 19:56:21', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2008, '2019-07-17 20:02:07', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2009, '2019-07-17 20:04:30', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2010, '2019-07-17 20:04:03', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2011, '2019-07-17 20:04:37', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2012, '2019-07-17 20:05:53', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2013, '2019-07-17 20:07:16', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2014, '2019-07-17 20:09:43', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2015, '2019-07-17 20:10:22', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2016, '2019-07-17 20:13:52', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2017, '2019-07-17 20:16:47', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2018, '2019-07-17 20:17:40', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2019, '2019-07-17 20:20:02', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2020, '2019-07-17 20:24:17', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2021, '2019-07-17 20:23:08', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2022, '2019-07-17 20:28:07', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2023, '2019-07-17 20:29:28', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2024, '2019-07-17 20:32:21', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2025, '2019-07-17 20:46:58', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2026, '2019-07-17 20:56:33', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2027, '2019-07-17 21:00:51', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2028, '2019-07-17 21:01:29', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2029, '2019-07-17 21:11:07', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2030, '2019-07-17 21:35:40', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2031, '2019-07-17 21:40:46', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2032, '2019-07-17 21:43:18', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2033, '2019-07-17 21:45:00', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2034, '2019-07-17 21:48:25', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2035, '2019-07-17 21:48:39', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2036, '2019-07-17 21:52:26', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2037, '2019-07-17 21:54:49', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2038, '2019-07-17 21:58:18', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2039, '2019-07-17 22:00:36', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2040, '2019-07-17 22:06:51', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2041, '2019-07-17 22:10:48', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2042, '2019-07-17 22:12:37', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2043, '2019-07-17 22:15:30', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2044, '2019-07-17 22:28:58', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2045, '2019-07-17 22:30:57', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2046, '2019-07-17 22:32:17', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2047, '2019-07-17 22:36:20', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2048, '2019-07-17 23:25:50', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2049, '2019-07-17 23:27:23', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2050, '2019-07-17 23:28:54', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2051, '2019-07-17 23:34:46', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2052, '2019-07-17 23:36:22', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2053, '2019-07-17 23:40:15', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2054, '2019-07-17 23:40:59', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2055, '2019-07-17 23:47:49', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2056, '2019-07-18 00:09:12', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2057, '2019-07-18 00:12:22', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2058, '2019-07-18 00:36:06', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2059, '2019-07-18 00:40:01', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2060, '2019-07-18 00:43:11', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2061, '2019-07-18 00:50:15', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2062, '2019-07-18 00:57:41', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2063, '2019-07-18 01:06:52', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2064, '2019-07-18 01:17:14', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2065, '2019-07-18 01:30:26', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2066, '2019-07-18 01:43:57', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2067, '2019-07-18 01:46:59', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2068, '2019-07-18 01:47:59', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2069, '2019-07-18 05:16:57', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2070, '2019-07-18 05:17:42', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2071, '2019-07-18 05:20:56', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2072, '2019-07-18 05:27:33', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2073, '2019-07-18 05:58:07', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2074, '2019-07-18 06:38:01', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2075, '2019-07-18 08:57:07', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2076, '2019-07-18 08:57:10', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2077, '2019-07-18 09:31:48', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2078, '2019-07-18 09:31:50', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2079, '2019-07-18 09:31:52', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2080, '2019-07-18 09:40:32', 'PARKENT 19 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2081, '2019-07-18 09:40:35', 'PARKENT 19 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2082, '2019-07-18 10:08:53', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2083, '2019-07-18 10:08:55', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2084, '2019-07-18 12:21:16', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2085, '2019-07-18 12:21:18', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2086, '2019-07-18 12:21:23', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2087, '2019-07-18 12:32:45', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2088, '2019-07-18 12:32:47', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2089, '2019-07-18 12:39:17', 'PARKENT 5 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2090, '2019-07-18 12:39:20', 'PARKENT 5 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2091, '2019-07-18 12:55:24', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 44, 0, 0),
(2092, '2019-07-18 13:16:06', 'ШОПИРЛАР ЗАЯФКА ОЛИЛАР КУПАЙИБ КЕТИ', 0, 44, 0, 0),
(2093, '2019-07-18 14:07:16', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2094, '2019-07-18 14:07:18', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2095, '2019-07-18 14:11:52', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2096, '2019-07-18 14:11:56', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 46, 0, 0),
(2097, '2019-07-18 14:59:55', 'YEVRO MED GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2098, '2019-07-18 15:00:00', 'YEVRO MED GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2099, '2019-07-18 15:00:09', 'ШОПИРЛАР ЗАЯФКА ОЛИЛАР КУПАЙИБ КЕТИ', 0, 44, 0, 0),
(2100, '2019-07-18 15:08:06', 'NAVOIY 66 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2101, '2019-07-18 15:08:09', 'NAVOIY 66 GA YURVORILAR ILTIMOS', 0, 46, 0, 0),
(2102, '2019-07-18 16:06:30', 'ШОПИРЛАР ЗАЯФКА ОЛИЛАР КУПАЙИБ КЕТИ', 0, 44, 0, 0),
(2103, '2019-07-18 16:56:19', 'ШОПИРЛАР ЗАЯФКА ОЛИЛАР КУПАЙИБ КЕТИ', 0, 17, 0, 0),
(2104, '2019-07-18 16:59:06', 'ОФЕСГА УЧРАМАГАН ШОПИРЛАР ТУЛОВДИ КИЛИБ КЕТИЛАР ', 0, 17, 0, 0),
(2105, '2019-07-18 18:25:52', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2106, '2019-07-18 18:38:48', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2107, '2019-07-18 18:40:21', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2108, '2019-07-18 18:43:14', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2109, '2019-07-18 18:45:00', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2110, '2019-07-18 18:47:59', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2111, '2019-07-18 18:52:04', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2112, '2019-07-18 18:53:37', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2113, '2019-07-18 18:55:14', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2114, '2019-07-18 19:00:08', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2115, '2019-07-18 19:03:50', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2116, '2019-07-18 19:04:00', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2117, '2019-07-18 19:06:57', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2118, '2019-07-18 19:08:20', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2119, '2019-07-18 19:13:54', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2120, '2019-07-18 19:14:11', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2121, '2019-07-18 19:16:16', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2122, '2019-07-18 19:17:45', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2123, '2019-07-18 19:18:31', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2124, '2019-07-18 19:21:07', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2125, '2019-07-18 19:39:35', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2126, '2019-07-18 19:40:26', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2127, '2019-07-18 19:41:46', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2128, '2019-07-18 19:42:37', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2129, '2019-07-18 19:42:56', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2130, '2019-07-18 19:44:27', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2131, '2019-07-18 19:45:18', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2132, '2019-07-18 19:46:55', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2133, '2019-07-18 19:52:28', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2134, '2019-07-18 19:53:18', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2135, '2019-07-18 19:56:05', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2136, '2019-07-18 19:57:17', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2137, '2019-07-18 19:58:03', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2138, '2019-07-18 20:00:41', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2139, '2019-07-18 20:02:27', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2140, '2019-07-18 20:04:12', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2141, '2019-07-18 20:09:31', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2142, '2019-07-18 20:14:27', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2143, '2019-07-18 20:18:38', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2144, '2019-07-18 20:21:38', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2145, '2019-07-18 20:28:21', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2146, '2019-07-18 20:33:55', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 47, 0, 0),
(2147, '2019-07-18 20:46:06', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2148, '2019-07-18 20:48:53', 'PLANGA PLANGA', 0, 50, 0, 0),
(2149, '2019-07-18 20:48:56', 'PLANGA PLANGA', 0, 50, 0, 0),
(2150, '2019-07-18 20:48:58', 'PLANGA PLANGA', 0, 50, 0, 0),
(2151, '2019-07-18 20:49:00', 'PLANGA PLANGA', 0, 50, 0, 0),
(2152, '2019-07-18 20:50:25', 'ЗАЯВКАЛАРГА ЮРИБ БЕРИЛАР ХУРМАТЛИ ХАЙДОВЧИЛАР ', 0, 52, 0, 0),
(2153, '2019-07-18 20:59:39', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2154, '2019-07-18 21:01:45', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2155, '2019-07-18 21:18:04', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 52, 0, 0),
(2156, '2019-07-18 21:22:20', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2157, '2019-07-18 21:24:01', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2158, '2019-07-18 21:39:48', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2159, '2019-07-18 21:39:57', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 52, 0, 0),
(2160, '2019-07-18 21:41:06', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2161, '2019-07-18 21:47:58', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2162, '2019-07-18 21:57:59', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2163, '2019-07-18 22:05:12', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2164, '2019-07-18 22:27:50', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2165, '2019-07-18 22:32:08', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2166, '2019-07-18 23:24:42', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2167, '2019-07-18 23:57:20', 'ШОПИРЛАР ЗАЯВКАГА ЮРИЛАР', 0, 47, 0, 0),
(2168, '2019-07-19 00:01:13', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2169, '2019-07-19 00:01:58', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2170, '2019-07-19 00:07:26', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2171, '2019-07-19 00:11:06', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2172, '2019-07-19 00:19:59', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0),
(2173, '2019-07-19 00:20:30', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 47, 0, 0),
(2174, '2019-07-19 00:27:45', 'BUSHLAR ZAYAVKAGA YURVORILAR ILTIMOS', 0, 52, 0, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `car_model`
--

CREATE TABLE `car_model` (
  `id` int(11) NOT NULL,
  `name` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `car_model`
--

INSERT INTO `car_model` (`id`, `name`) VALUES
(105, ''),
(1060, '05.06.2018'),
(4, 'COBALT'),
(790, 'Espero'),
(6125, 'KAPTIVA'),
(2239, 'LABO'),
(3399, 'LACETTI'),
(2560, 'LADA  X  RAY'),
(6058, 'LANOS'),
(4002, 'LARGUS'),
(8829, 'Lasetti'),
(7146, 'LASSETI'),
(3440, 'LEGANZA'),
(1, 'MATIZ'),
(4003, 'MATZ'),
(2881, 'NEKSIA'),
(2203, 'NEKSIA 1'),
(556, 'NEKSIA 2'),
(2238, 'NEKSIA 3'),
(3491, 'NEKSIA1'),
(3956, 'NEKSIA2'),
(2, 'NEXIA'),
(363, 'NEXIA 1'),
(124, 'NEXIA 2'),
(460, 'NEXIA1'),
(583, 'NEXIA2'),
(10533, 'Ok'),
(3438, 'Opel'),
(4286, 'SPAKRK'),
(3, 'SPARK'),
(3400, 'TESTER'),
(2634, 'TICO'),
(4421, 'TIKO'),
(9971, 'ЖЕНТРА'),
(150, 'КАПТИВА'),
(1061, 'КАПТИВА 4'),
(482, 'Кобалт'),
(70, 'Ласетти'),
(79, 'Матиз'),
(394, 'Матиз бест'),
(432, 'Нексия'),
(555, 'НЕКСИЯ 1'),
(141, 'Нехиа'),
(334, 'Нехиа 1'),
(396, 'Нехиа 2'),
(3511, 'Нехиа1'),
(421, 'Опел'),
(1066, 'Рейсер'),
(403, 'Спарк'),
(1056, 'Тико'),
(489, 'Эсперо');

-- --------------------------------------------------------

--
-- Структура таблицы `car_payment`
--

CREATE TABLE `car_payment` (
  `id` int(11) NOT NULL,
  `date` datetime DEFAULT NULL,
  `car_id` int(11) DEFAULT NULL,
  `sum` float DEFAULT 0,
  `reason` int(11) DEFAULT NULL COMMENT '1 - qarz yozildi, 2 - pul tulandi, 3 - chegirma',
  `driver_id` int(11) DEFAULT NULL,
  `payment_type_id` int(11) DEFAULT NULL,
  `comments` varchar(300) DEFAULT NULL,
  `discount` float DEFAULT 0,
  `exp_date` datetime DEFAULT NULL,
  `points` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `client`
--

CREATE TABLE `client` (
  `id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `token` text DEFAULT NULL,
  `blocked` int(11) NOT NULL DEFAULT 0,
  `pincode` varchar(20) DEFAULT NULL,
  `counter1` int(11) DEFAULT 0,
  `counter2` int(11) DEFAULT 0,
  `counter2_date` date DEFAULT NULL,
  `counter3` int(11) DEFAULT 0,
  `code` varchar(12) DEFAULT '',
  `counter3_date` date DEFAULT NULL,
  `deposit` float DEFAULT 0,
  `password` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `client`
--

INSERT INTO `client` (`id`, `name`, `phone`, `group_id`, `token`, `blocked`, `pincode`, `counter1`, `counter2`, `counter2_date`, `counter3`, `code`, `counter3_date`, `deposit`, `password`) VALUES
(102802, 'Alisher Djalalov', '+998916848100', NULL, 'dRYVbfakHAQ:APA91bFkWCI0dA_KD79BhSDYPPvpAjf_jLbegziYz22cV85GtkVhG5mqC9leAdxRVGzFQb0Ftz0RABXBUdm6s-E4ixNlEhy1T6kJWao3iWli12u8ZZZ9Yac3-8O6vccvWxc8t6KoTJQN', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'A1983$1'),
(114097, 'Mashhura Tôymurodova', '+998991281221', NULL, 'dr62UZnL3w4:APA91bFFKAPPi2HLb6uemVFgLnns6LUFzCq3cYxmPRTSKr3-mxX2AP3p_MWdR1X0K_fZG-2Or6ff5dDXe16tUnpFRu3D2HrXfcdom7hnjBwjJhaLdrr4nbdsb7oX54BAH5H243XDCC6J', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114098, 'saidkamol', '+998997297857', NULL, NULL, 0, NULL, 0, 0, NULL, 0, '850737', NULL, 0, 'password'),
(114099, 'Yulduzxon', '+998944918747', NULL, 'fRU_bXkjGS4:APA91bF924C-0zOSawLIl_b4fiDdP4tafOxHyFRBZjG7G2Hk2dz8RZAqAfAAq-dpLBZT91uXCsozWdMcE_xIlq4OMCjZHsBlxGGEphNUmTheDWqWDJTsPMHvyH0-tc1pts7rtsgcWd_a', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114100, 'yusuf', '+998938484455', NULL, 'cyJyD4UqBzI:APA91bELxE2ycI0sVSyOqRWbYGKCWrec-hgT5SOXmCeiaaTS8S4MU4IwpIBFrrJGHnbdl57AQJjUpGwKdvALMNGd-cpSpCM2COLENLnE4MGimI5mJ-3g02BFm52zbe1NzZpHlCXNJ5Jb', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114101, 'mohina', '+998973349300', NULL, 'dWQet0XFGI0:APA91bFSDqfMy-ho3140ht7Iib6nvkSnkvUlIFtYTpqvCgObDnqx-gtM--SmDffhhbkwLj0HYkDDLrJa8tNRY2oyZcXcsCGWmXSfkjrGNkBk4ux4rcHW0Yu7BGYMC_Y-Y3hK-if-1a5t', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114102, 'zumradxon', '+998911502856', NULL, 'eNzNGwUxJ78:APA91bH4mg4S7XxQqP-FOPnOGhbt916DoDJWEfvDdmSMkbw5CtwqBBDm9Q-andem0GfoVboY5Rp5sq1oHge3Y0kD0415mTHAniK6XKZY89nVxCAGIQZJprnGODuI4VXUDUok2d7y0SM4', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114103, 'Nilufar', '+998903653805', NULL, 'eL9BGDoFjQg:APA91bG5WJN7m02Cg-gLJd35buMn_-Ze1d3FO0Zqg46UsCZnv8zb68d2TCnYv9LyQwRz-pzZkYoRCWQKzsm9cqH6ZVFeiFrkE-Y1_PoMjbkE2gwPfa5ulrR3p3CVFnpDiCpwqZbX4K_i', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114104, 'Qaxramon', '+998908555655', NULL, 'fZF4Ja0Re3g:APA91bHQRwGdcnTqQhzyrGBBOpQEuodPbsa5txdHh8hsqx6pjJrnnyXPNJXYFJnt_PXhHVqTbfd_uTfU0XdmZ3SvcjyQ0rS5V814E5rzQ1X_jZ2ydDnbFm6GGV_MNeowmSZfGiYnJUu0', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114105, 'Xumorabonu', '+998909706572', NULL, 'f5lYjji0up4:APA91bFu2kvVxgTqKPVykMSvIvMILsQNeqqCDVyrs23DX9HQeK-tjKRBZWhrHVtOZWRpHOVgAy4KoZkcDnHkPTO36glvxiLztCiPojTu9RfISmh5P8lnx_gdXXzGfqzEtChTkobEUvBi', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114106, 'Mirjalol', '+998900559197', NULL, 'd-4VRtL5dfo:APA91bEUxos13t5ZSvy1b_F2jbBvy9imvjbUHC6nXLq2zeNDMHaScgKqojG3BilbgXWjUlSsNCj1hgp2EBhN_Hm9d4B72pQQ35EwYsKK1uDKk8eaeQOD6UhBdfqlCBK8_sXMr25a8iUn', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114107, 'ziyohon', '+998333790070', NULL, 'cwePjxiOqMY:APA91bFjai8A0snFhuNJxAfIhKpRYRUPvfelOCxu45SXsMBJBXrExJYN-6KA59a9Hf0wiKQVFkXznktS-4_NgK4vjemrYLPVxZaBOFh-FjgQq9Gjw58WD8G_OV2LZyIILZ9TVZz9R1vU', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114108, 'Malikaxon', '+998900557479', NULL, 'davpawJV67Q:APA91bGL_oiLpPW56XvcJePdxZlTMTRzfCeom6LntUWG1BTlMC3U_KsPZbxmiWm4Ud-bLwawBJPUyE4Zsoi0Pncm-IJSr3hvgKPxyHI1oO92QqKV0nX_katOg-Wshi6Q4wQhAwC95TGC', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114109, 'Masuma', '+998913479515', NULL, 'ecg3NAgBG8k:APA91bGYeXG4IuLC4prU9-3ILL-O3l7GfSU0MMZa30eAaH7qPFnYdSlQLlR3jVR1T0xHBYoo3fldMQDOQbL1U6q4p0R0WL5z1HmK5fZ-_P1A7LuZl8n_1hplC3pAf69_eAMwtrfUEK2G', 0, NULL, 0, 0, NULL, 0, '921380', NULL, 0, 'A1983$1'),
(114110, 'аюбхон ', '+998945107717', NULL, 'cjDLASHj50s:APA91bFY4CB3juh5yDLmiVMhsXFhL0Wx2Z58EgDppu0MDA7iDsSwvFfrBEVphJZbLTwZMNDmxI8SUAJP6D7eWenj-eYeackczCn39CePXxqI3NBytnqUJbi3dp75mNedfEUNEWE39pTG', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114111, 'mohirjon', '+998912005206', NULL, 'cbxHrGExnSQ:APA91bHUurqBxZpOFVB9HWSYDUoUTPeKL1aQ6i4SDSNOwxs79pr7I2DC4AogJHy3uzLiOqyqxoVyZCvXNZaVXlYEf5rR6PM0HINo5TSF6JKGVaLkkTcjf7kIhTcyRpczXXhjcEMl67f7', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114112, 'Амир Рахмонкулов', '+998999555948', NULL, 'eXIKaPXPAbw:APA91bFAYdx_iPZ578EEQGCmDXDcJuNX5a4XwUEhwez7_82TyY6Q94FjyfTSXbQj24kU8-vi_CZu6QOiHbXLkNpxALE7pHG9VuSkgALIDqPwcXnXG4FIUzebq3mk5HxCeaBcjD_Mcs2t', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114113, 'Нилуфархон', '+998916957739', NULL, 'dl1cyoG-9FY:APA91bG4noqZDpxbJHTRAV5720AxEHCK1CpUF_LFLerzTMpmH_N69YuokVAahGKirY0r9t-_Ly3yEbDzIydutq1c_xvdl3oZPXPFY7Jpypm8mL-JH10wKRQgT0eccShNGe11O6s1j3pE', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114114, 'шахноза', '+998998110936', NULL, 'fWRY-Bq4UF8:APA91bFIfsPOOMME6nJf75uVaS21FvW3xPpJQqJyThTjWkZ5umyOXBUJFzNquiwbe5UE8kQDNuusHD0zbUkTwyhkCxquOREoF7xOyxYYbYoxAfF-pZcUymnrKMCGkD6OBaxB2T2jNXkb', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114115, 'barnoxon', '+998905675737', NULL, 'c1yIQG6eBq0:APA91bE6P9mYN-qPxiKua3WfjRjnQDDcu1BxqwsK4bruPRThgYCWtIWfKoFCGRSYAh4UJWLd9US55w0a9rKuV0diK6vJOZR2-IgotkAIl1pYbjIpYZfEKNkPPO-IvJOp9r4iATIJQM0o', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114116, 'Hanifa ', '+998903430636', NULL, 'fxpyHFgYGXM:APA91bHY9vjM3z-i8FM6CHK5E7V193B9umn66OXiVdYAfNgn7Srq5HRq0DZd9OHEVDYhDzdYUJ9ofYskV1qsltYHu2meg1zNpNbjO_Im12jCRe_clZ6wKn2ksCQiE4UGnFr-Tx1YaPNV', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114117, 'xusnidaxon', '+998900556942', NULL, 'dZBucTssgw4:APA91bHq3bFTo2iwfyXsjLOPGp0THVV7A_ISpRdB4EJ_pSz_DYQF_f30CrgwUWuTdwoNfQ5xbhLjYaH9sHjLo_pQ11rncaSMWomNJJZRdfZyRBTrdkUOsY0zncg--RKoUrM6lmFg6Xb3', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'A1983$1'),
(114118, 'Asliddin', '+998973780373', NULL, 'cNn4ZI2MT5M:APA91bEFlWClz-RzMTmBZUmqL4CC79Sflt06TlI7v1u7QQFZpRta0VBb2awwGVztpWtWKCnR6goePoyUGfU62tZfGTgs9LT4qpQXatRZwc_nyPy-o4STkQAARunGgEj3OUIsIC27ejiD', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114119, 'Абдрашит', '+998906003434', NULL, NULL, 0, NULL, 0, 0, NULL, 0, '603909', NULL, 0, 'password'),
(114120, 'Alımova Xurshıda', '+998905648974', NULL, 'cL5qWkDZLDQ:APA91bFJ3gYlLr5xy2tYV1lHs-QNBFhuOX7sCMhyBaRlISL0MjUFGgc2sEQqUgzYFA1T6gMiRf-HIZ5dt8Q8h1F8Z3wkWbjX0zIDi_-pH4p4Xpe8mVYG8J7iUQZex6ELwCG3JCGbUPdb', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114121, 'Салиха', '+998911461618', NULL, 'dsX7kX_d994:APA91bHNksJJ_c4gpHvSjxbvSgToe84RzmFttmWihfcK2VDV7DqfInA27xF5tW-xi7ji75sEB1uN-ofhdwI8bE18fstW_hnKak8hFazFwQSTj2xH2KnFXBA0I5mt5J_RcLE5cCQq6D7t', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114122, 'Зухра', '+998916887755', NULL, 'c8MqOqh8vN8:APA91bHIPrljJIL-bX3oZYejVyCX2dlgBfJwtcJPVimJKk3ZNmgBwqWO_dGi_5qQvu4hLNP2f9norTWfubuHPt2d5REpnJKQ41xq8RJjtckOA7Jixyjg3PEvq-ctmfZ9wzzZ288_szYV', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114123, 'Azizbek ', '+998933329199', NULL, 'emp0mZZywaA:APA91bGWkFBeyP6r2zDVo4Y-bjCr9P4FwEId3paJa0FHASoajvhAxpkmQdVniAPxfTUPnwJQEzcwPEQgSijGA0gyeAwDlZ2CC0QjuEz_VIyMg1C-QNCkUzGeF2pDu-BxSLTGpmnwhW62', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114124, 'нигора', '+998331479093', NULL, 'ez1QL5DXfck:APA91bE_i3RMJPYFetAl4kIlmdtMPkEEQtMoAW11l8Fu6ZWvQi2Zvb73uvLlMckZkpDKM8SVEiMkGE9gkLb8CZShlQdS0u-LA5QrrBoedTsuAwncJ4KsbifI5cb5O9dOen62lNCJ5IMc', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114125, 'Ботирова', '+998905674196', NULL, 'dEdV_UoTY6c:APA91bEoNNAOdpmogJD3rAT-GEv3xDdWLSwxu_jPD5sRy_6K-R0CUb9q8Fpu7Tpt9WX3Fw_mSeUMaSzJPBszyZegsjugGNOnNKtSxiyOcHRbCu5E-ArmqBbkA5vH4MUkDS8QMyNxEikB', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114126, 'Ozodbek', '+998997425808', NULL, 'ctNtbWm7sQw:APA91bE8nGBs6O3scdyS3L8_AmrnKq2LAnQAxBsHDkutLWHI_qxV-gzAZvo7JYSf_2TPiDODHBuA-o4q_JQo0gcNqqQpqYRQ0Dr0uR9tahGkSv71u1oi7WT0IPUOPKUvjf7X8cXdTqlk', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114127, 'Doniyorjon', '+998944492525', NULL, 'coGepl9RWmo:APA91bHob1YAmD06xZ5sQjLtE2PAaO8UuCLRs0ZsE7ZPRB3T_fzOM8nYivU_ZvhXVypl24DLxDJNu2NfTcbihECbLtYzPHbDclND8t83-5eLuM5iJrk3hs4yvwjq2hOMbOFb7wZupW1p', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114128, 'Otabek', '+998911110054', NULL, 'cRuim_3M3Kc:APA91bEhNHP5oV-GvpibhjwHc4fk2Ulv9RkYvcMVfeaf5VzQa5FsVQLZDnek2LNJzIU8crAEr-vG4GN_zMfbNa9s8EU8mmWBeAd64Fr7MnK0cS-NMgYdSt-Xu7rfxV-m-LTEblP1I5Jb', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114129, 'Abdumutallib', '+998994870127', NULL, 'eBmZlTXgtH0:APA91bG1YPUG1XwaZdHZg_1EY1jXQZb9VHgDl6a7IH9Iqt_bWhwsO5VVp8mjaVsrWK9afkVgS2bjjPIQDP6Rm9p4aAM3PNdpTscDOCwHW4AvscsOCBbfQDudBhZPZGlLwHba0lpQB-ml', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114130, 'Halima', '+998994413575', NULL, NULL, 0, NULL, 0, 0, NULL, 0, '792752', NULL, 0, 'password'),
(114131, 'Afruza Shennazarova', '+998973479304', NULL, NULL, 0, NULL, 0, 0, NULL, 0, '935067', NULL, 0, 'password'),
(114132, 'Afruza Shennazarova', '+998975479304', NULL, 'dtMIMVzP3nQ:APA91bFmm2To_S-gRS-nEPxEvd4QwpNiHWl9TrrXz9B6-4A8b6m2ISQuTvwjYQp8KwYYgunoQvdkIvjSMLmhjTbat06AtKRfCVi3Vj1EhCKv8vZ2LKPEcuLrIkCKTxFXSzaPMTXP-Lck', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password'),
(114133, 'Qosimova', '+998975018068', NULL, 'dZhUIRp6PA0:APA91bG5-klqDFemYmGIEjqyu-WvX18Pk_t4yG4I0gwvUB1ZHgZ4dzA_a-HwwCf8wxZgtBo4cfbjfvLNl385OhCwiEV8WVAQsjQMquXXEMhL3_4bdxZKJOjrIq9g_pvHGMK3vfafkXiG', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'A1983$1'),
(114134, 'Miss', '+998970409292', NULL, 'fw9jxN25e04:APA91bHiZsJRj9G7Nu10B7oRd6B4wwoF930Zq0vb7GrZumSYoCINnw1sGlJZjvktZBXiqSeMkia4ngOZr7wKE40BBAW9B3g9S7BN_LPY8A0fUBQRdLHlHE47paDewhR8EggImOPI230n', 0, NULL, 0, 0, NULL, 0, '', NULL, 0, 'password');

-- --------------------------------------------------------

--
-- Структура таблицы `client_comment`
--

CREATE TABLE `client_comment` (
  `id` int(11) NOT NULL,
  `date_created` datetime DEFAULT NULL,
  `comment` varchar(240) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL,
  `reply` varchar(240) DEFAULT NULL,
  `sender` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `client_comment`
--

INSERT INTO `client_comment` (`id`, `date_created`, `comment`, `client_id`, `reply`, `sender`) VALUES
(1, '2019-03-05 03:52:36', 'Dastur zurakan', 1, NULL, 0),
(2, '2019-03-05 03:54:06', 'Jfjfi', 1, NULL, 0),
(3, '2019-03-05 03:55:57', 'Sizgayam rahmat', 1, NULL, 1),
(4, '2019-03-05 03:56:04', 'Gjfjj', 1, NULL, 0),
(5, '2019-03-05 03:56:10', 'dskjsdlkfjksf', 1, NULL, 1),
(6, '2019-03-05 03:56:11', 'sdfsdf', 1, NULL, 1),
(7, '2019-03-05 03:56:12', 'sdf', 1, NULL, 1),
(8, '2019-03-05 03:56:12', 'dsf', 1, NULL, 1),
(9, '2019-03-05 03:56:13', 'sdf', 1, NULL, 1),
(10, '2019-03-05 11:38:36', 'яхши зур келилар кечкурин', 3, NULL, 0),
(11, '2019-03-08 20:36:32', 'зур праграммакан заминга рахмат', 72860, NULL, 0),
(12, '2019-03-08 21:00:02', 'qachon bepuli 7 chisi bepul buladi', 74016, NULL, 0),
(13, '2019-03-09 05:50:18', 'yangilangan programma umuman qulay emas. yoqmadi manga. sababi: sms ovozi eshitilmayabdi.', 73734, NULL, 0),
(14, '2019-03-10 18:15:39', 'Эски буютмани учириб булмаяпти', 74019, NULL, 0),
(744, '2021-04-26 15:57:44', 'заказ беродим олиндими анча вакт утди', 105190, NULL, 0),
(745, '2021-05-22 11:11:40', 'картошка йўқми', 108218, NULL, 0),
(746, '2021-05-26 18:39:48', 'telilaga tushib bumayapti zakas qachon keladi', 103963, NULL, 0),
(747, '2021-06-05 10:05:24', 'ассалому алейкум', 109012, NULL, 0),
(748, '2021-06-05 10:05:32', 'богланолмаяпман', 109012, NULL, 0),
(749, '2021-06-05 10:05:46', 'Доставкачи манга тел киворсин', 109012, NULL, 0),
(750, '2021-06-05 10:06:00', '2кг шакар хам кушволишсин', 109012, NULL, 0),
(751, '2021-06-06 13:07:47', 'Ассалаума алейкум. Бу ерда базор нархидан кура нархлар экки баравар киматку. Нархларни улгуржи нархда куйишингиз керак манимча.', 114042, NULL, 0),
(752, '2021-06-07 20:28:46', 'Нархларни ўзгартириш керак шекилли бақлажон 5 минг бозорда силарда 25минг турибди', 108218, NULL, 0),
(753, '2021-06-07 20:29:22', 'гархларга эьтибор бериб турилар', 108218, NULL, 0),
(754, '2021-06-12 11:36:47', 'Бугун заказ бермагандим', 108978, NULL, 0),
(755, '2021-06-12 11:37:23', 'Буюртмангиз келди, дейишяпти', 108978, NULL, 0),
(756, '2021-06-13 18:02:46', 'теларинга тушиб бумаяпти заказимизи тезлатворилар илтимос', 103361, NULL, 0),
(757, '2021-06-22 09:45:33', 'Заказ бериб пойладик, кабул килдик, дейишмади. Энди обеддан кейин келинглар, илтимос, чунки уйда хечким йук', 108978, NULL, 0),
(758, '2021-06-25 07:03:19', 'dukon qachon ochiladi', 106715, NULL, 0),
(759, '2021-07-04 13:55:31', 'товуқ махсулотлариниям кфсва грилларниям доставка йўлга қўйинглар', 108218, NULL, 0),
(760, '2021-07-06 13:45:14', '1 soat dayan kemedi i zakaz', 106917, NULL, 0),
(761, '2021-07-06 13:45:28', 'Iwlayabsilami ozi', 106917, NULL, 0),
(762, '2021-08-02 22:08:07', 'salom', 102802, NULL, 0),
(763, '2021-08-27 10:36:19', 'assalomu alaykum buyurtma qilgandim uzoq qolib ketishdi', 113611, NULL, 0),
(764, '2021-08-30 18:59:37', 'Ассалому алайкум Тошкент группами бу', 114122, NULL, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `client_group`
--

CREATE TABLE `client_group` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `deposit` double DEFAULT 0,
  `pincode` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `client_group`
--

INSERT INTO `client_group` (`id`, `name`, `deposit`, `pincode`) VALUES
(1, 'Software Systems', 0, NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `client_partner_rating`
--

CREATE TABLE `client_partner_rating` (
  `id` int(11) NOT NULL,
  `phone` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `partner_id` int(11) DEFAULT NULL,
  `rating` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

-- --------------------------------------------------------

--
-- Структура таблицы `client_product_review`
--

CREATE TABLE `client_product_review` (
  `id` int(11) NOT NULL,
  `client_id` int(11) DEFAULT NULL,
  `product_id` int(11) DEFAULT NULL,
  `comments` varchar(255) DEFAULT '500',
  `rating` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `client_product_review`
--

INSERT INTO `client_product_review` (`id`, `client_id`, `product_id`, `comments`, `rating`) VALUES
(1, 106788, 1559, '', 5),
(2, 103195, 1210, '', 5),
(3, 105338, 1266, '', 5),
(4, 106839, 1972, '', 5),
(5, 106788, 1669, '', 3),
(6, 106810, 1315, '', 5),
(7, 104043, 1264, '', 5),
(8, 107266, 1264, '', 5),
(9, 107497, 1913, '', 5),
(10, 107565, 1209, '', 5),
(11, 107660, 1308, '', 5),
(12, 107703, 1854, '', 5),
(14, 107728, 1237, '', 1),
(15, 106687, 2024, '', 5),
(16, 107270, 1281, '', 5),
(17, 107826, 1211, '', 3),
(18, 107826, 1948, '', 4),
(19, 108186, 1364, '', 1),
(20, 107491, 1981, '', 5),
(21, 107491, 1985, '', 5),
(22, 107491, 2031, '', 5),
(23, 104894, 1899, '', 5),
(24, 108288, 2015, '', 5),
(25, 108445, 1918, '', 5),
(26, 108326, 1265, '', 5),
(27, 108532, 1947, '', 5),
(28, 107826, 1663, '', 4),
(29, 107826, 1612, '', 5),
(30, 108647, 1690, '', 5),
(31, 108281, 2104, '', 5),
(32, 108815, 1216, '', 5),
(33, 108758, 1232, '', 4),
(34, 108869, 1237, '', 5),
(37, 105145, 1237, '', 5),
(42, 105145, 1218, '', 5),
(43, 105145, 1219, '', 5),
(44, 105145, 1232, '', 5),
(45, 105145, 1239, '', 5),
(46, 106687, 2015, '', 2),
(47, 106574, 2161, '', 5),
(48, 109140, 2250, '', 5),
(49, 109211, 1672, '', 5),
(50, 105023, 2270, '', 5),
(51, 109167, 1209, '', 5),
(52, 109330, 1433, '', 5),
(53, 108491, 1322, '', 4),
(54, 109379, 1474, '', 2),
(55, 108933, 2470, '', 5),
(56, 109402, 1211, '', 5),
(57, 109342, 1524, '', 2),
(58, 109342, 2029, '', 5),
(59, 109423, 1948, '', 5),
(60, 109531, 1606, '', 1),
(62, 108786, 1211, '', 4),
(63, 109015, 1540, '', 5),
(64, 108615, 1282, '', 5),
(65, 109996, 1920, '', 5),
(66, 110087, 2003, '', 5),
(67, 110125, 2003, '', 5),
(68, 109056, 1267, '', 5),
(69, 108798, 2003, '', 5),
(70, 111171, 1408, '', 5),
(71, 111171, 1427, '', 5),
(72, 111171, 1429, '', 5),
(73, 102984, 1366, '', 5),
(74, 109753, 1966, '', 5),
(75, 102852, 2683, '', 5),
(76, 102852, 2684, '', 5),
(77, 110684, 1326, '', 5),
(78, 106524, 1411, '', 5),
(79, 111503, 1993, '', 5),
(80, 111507, 1265, '', 5),
(81, 111713, 1533, '', 5),
(82, 107443, 1221, '', 5),
(83, 108783, 1272, '', 5),
(84, 111544, 2736, '', 3),
(85, 111544, 2755, '', 1),
(86, 108493, 2636, '', 5),
(87, 108493, 2741, '', 5),
(88, 108493, 2747, '', 5),
(89, 108493, 2710, '', 5),
(90, 108493, 2751, '', 5),
(91, 108493, 2752, '', 5),
(92, 108493, 2753, '', 5),
(93, 108493, 2754, '', 5),
(94, 111326, 1209, '', 5),
(95, 109360, 2696, '', 5),
(96, 111856, 1229, '', 5),
(97, 108854, 2656, '', 5),
(98, 106936, 1517, '', 5),
(99, 108493, 2746, '', 5),
(100, 111708, 2345, '', 5),
(101, 111708, 2344, '', 5),
(102, 111708, 1451, '', 5),
(103, 110319, 1288, '', 5),
(104, 110819, 2732, '', 5),
(105, 112001, 1404, '', 5),
(106, 104012, 1436, '', 5),
(107, 108970, 1603, '', 5),
(108, 108854, 2637, '', 1),
(110, 109436, 1209, '', 5),
(114, 102802, 2523, '', 5),
(115, 112153, 2144, '', 5),
(116, 112153, 1334, '', 5),
(117, 112153, 1260, '', 5),
(118, 103988, 2003, '', 5),
(119, 110684, 2682, '', 5),
(120, 109152, 1915, '', 5),
(121, 112351, 2637, '', 5),
(122, 110512, 2003, '', 5),
(123, 112102, 1690, '', 5),
(124, 112286, 1300, '', 5),
(125, 110030, 1621, '', 5),
(126, 106779, 1551, '', 4),
(127, 106787, 2864, '', 5),
(128, 112237, 1247, '', 5),
(130, 112489, 1262, '', 5),
(131, 105004, 1489, '', 1),
(132, 111853, 1284, '', 5),
(133, 111853, 2651, '', 5),
(134, 111853, 2799, '', 5),
(135, 111853, 2800, '', 5),
(136, 111853, 2801, '', 5),
(137, 111853, 2802, '', 5),
(138, 111853, 2804, '', 5),
(139, 111853, 2821, '', 5),
(140, 107332, 1956, '', 5),
(141, 111618, 2864, '', 5),
(142, 112307, 2490, '', 1),
(145, 112386, 2976, '', 5),
(146, 112692, 1231, '', 5),
(147, 109753, 2342, '', 5),
(148, 105779, 2420, '', 5),
(149, 112191, 2889, '', 5),
(150, 112761, 3105, '', 5),
(151, 103182, 3090, '', 5),
(152, 104161, 2522, '', 5),
(153, 112808, 2489, '', 5),
(154, 108493, 2748, '', 5),
(155, 110869, 2828, '', 1),
(157, 110047, 3225, '', 5),
(158, 103378, 1799, '', 5),
(159, 103378, 1627, '', 5),
(160, 105706, 1785, '', 5),
(161, 104035, 1524, '', 5),
(162, 112672, 1938, '', 5),
(163, 109979, 2889, '', 5),
(164, 112655, 1247, '', 3),
(165, 109979, 1524, '', 4),
(168, 107042, 2445, '', 5),
(169, 112918, 1540, '', 5),
(170, 112918, 1583, '', 5),
(171, 112918, 1628, '', 5),
(172, 112918, 1799, '', 2),
(173, 112918, 2013, '', 5),
(174, 112918, 2628, '', 5),
(175, 112918, 1251, '', 5),
(176, 112918, 2992, '', 5),
(177, 107634, 1230, '', 5),
(178, 112960, 1973, '', 5),
(179, 112960, 2120, '', 5),
(180, 108547, 1210, '', 5),
(181, 112575, 2790, '', 5),
(182, 112575, 2791, '', 1),
(183, 112968, 3191, '', 1),
(184, 112472, 1315, '', 4),
(185, 113005, 2789, '', 1),
(186, 113005, 1920, '', 1),
(187, 113006, 1505, '', 5),
(188, 113006, 1509, '', 4),
(189, 109452, 1524, '', 5),
(190, 112975, 2556, '', 2),
(191, 107744, 1540, '', 5),
(193, 106562, 1216, '', 5),
(194, 108080, 1792, '', 4),
(195, 109979, 2689, '', 5),
(196, 111538, 2889, '', 5),
(197, 111287, 3177, '', 5),
(198, 103014, 1489, '', 5),
(202, 113124, 2637, '', 5),
(204, 113124, 2789, '', 1),
(205, 108237, 1440, '', 5),
(206, 103399, 1533, '', 1),
(207, 103014, 1487, '', 2),
(208, 113278, 3191, '', 5),
(209, 113230, 1265, '', 5),
(210, 113278, 1577, '', 5),
(211, 113324, 2772, '', 5),
(212, 113324, 3171, '', 5),
(213, 113348, 3105, '', 5),
(214, 113025, 1210, '', 5),
(216, 113025, 3637, '', 5),
(217, 106839, 2811, '', 5),
(218, 106839, 1342, '', 5),
(219, 110602, 1663, '', 5),
(220, 107143, 2971, '', 5),
(221, 107143, 2969, '', 5),
(222, 113006, 1547, '', 5),
(223, 113006, 1548, '', 5),
(224, 113006, 1549, '', 5),
(225, 113006, 1550, '', 5),
(226, 113006, 1524, '', 1),
(227, 113006, 1489, '', 5),
(228, 113006, 2687, '', 5),
(229, 107618, 3176, '', 5),
(230, 113481, 1811, '', 5),
(231, 108891, 1249, '', 5),
(232, 102848, 1663, '', 5),
(233, 113450, 1212, '', 5),
(234, 107826, 1274, '', 4),
(235, 113006, 1811, '', 5),
(236, 107949, 3171, '', 5),
(238, 113025, 1209, '', 5),
(239, 113631, 3391, '', 1),
(240, 113794, 2954, '', 5),
(241, 106700, 1322, '', 4),
(242, 106700, 3008, '', 5),
(243, 106962, 1603, '', 5),
(244, 113856, 3171, '', 5),
(245, 103195, 1523, '', 5),
(246, 103297, 2973, '', 5),
(247, 113903, 1267, '', 5),
(248, 108237, 2957, '', 5),
(249, 109842, 1606, '', 5);

-- --------------------------------------------------------

--
-- Структура таблицы `config`
--

CREATE TABLE `config` (
  `name` varchar(50) NOT NULL,
  `value` varchar(500) DEFAULT NULL,
  `data_type` varchar(500) DEFAULT NULL,
  `description` varchar(500) DEFAULT NULL,
  `global` bit(1) DEFAULT b'0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `config`
--

INSERT INTO `config` (`name`, `value`, `data_type`, `description`, `global`) VALUES
('AddressOrder', '1', 'L', 'Mijoz manzillarini tartiblash usuli (0-sana bo\'yicha, 1-chaqiruv soni bo\'yicha, 2-alifbo bo\'yicha)', b'0'),
('AutoNum', '1', 'L', 'Avto pozivnoy raqami', b'0'),
('BlockIfIgnore', '120', 'B', 'Haydovchi buyurtmani olib, so\'ng bekor qilsa uni bloklash vaqti (minutlarda)', b'0'),
('BlockIfLate', '1', 'B', 'Haydovchi tanlagan vaqtiga yetib bormasa uni bloklash vaqti (minutlarda)', b'0'),
('BlockIfLateLimit', '2', 'L', 'Буюртмага неча минут кечикканда блоклаш қиймати', b'0'),
('CallerNumber', '+998996909707', 'S', 'Qo\'ng\'iroq qiluvchi nomer', b'0'),
('Company', 'BARAKA TOP', 'S', 'Kompaniya nomi', b'0'),
('DeleteOrderMode', '0', 'L', 'Buyurtmani o\'chirish rejimi: 0 - hamma foydalanuvchi o\'chirishi mumkin, 1 - faqat kiritgan odam o\'chira oladi', b'0'),
('DriverLicense', '0', 'B', 'Haydovchi litsenziyasini kiritish majburiyligi', b'0'),
('IEEmulation', '10000', 'L', 'Internet Explorer emulyasiya versiyasi', b'0'),
('OrderRenew', '1', 'B', 'Buyurtma vaqtini yangilash', b'0'),
('OrderRenewTime', '10', 'L', 'Ushbu vaqtdan (minutda) ko\'p bo\'lgan buyurtmalarni yangilab bo\'lmaydi', b'0'),
('PanelCols', '30', 'L', 'Mashinalar panelidagi ustunlar soni', b'0'),
('PanelRows', '2', 'L', 'Mashinalar panelidagi qatorlar soni', b'0'),
('ServerPath', '/baraka', 'S', 'Server manzili', b'0'),
('ServerPort', '80', 'L', 'Server porti', b'0'),
('ShowOrdersIndicator', '0', 'B', 'Dispetcherlarda buyurtmalar soni indikatorini ko\'rsatish', b'0'),
('SMS1', '1', 'B', 'Буюртма қабул қилингандаги SMS ёниқ/ўчиқлиги', b'0'),
('SMS2', '1', 'B', 'Ҳайдовчи етиб боргандаги SMS ёниқ/ўчиқлиги', b'0'),
('SMS3', '0', 'B', 'Буюртма бекор қилингандаги SMS ёниқ/ўчиқлиги', b'0'),
('SMS4', '0', 'B', 'Буюртма тугатилгандаги SMS ёниқ/ўчиқлиги', b'0'),
('SMSBalansLimit', '0.1', 'E', 'Minimal balans (paket olish uchun chegara)', b'0'),
('SMSBalansShablon', 'Balans.{[+\\-]?[0-9]*[\\.]?[0-9]*} y.e', 'S', 'Balans formati', b'0'),
('SMSBalansUssd', '*100#', 'S', 'Balansni tekshirish buyrug\'i', b'0'),
('SMSBekorVaqt', '15', 'L', 'Kechikkan SMS larni bekor qilish vaqti', b'0'),
('SMSBonus0', 'Bepul minimalkaga {11-%soni MOD 11} ta chaqiruv qoldi.', 'S', 'Bonus SMS bo\'lmaganda', b'0'),
('SMSBonus1', 'Sizga bepul minimal yo\'nalish taqdim etildi.', 'S', 'Bonus SMS bo\'lganda', b'0'),
('SMSFilter', '0', 'L', 'SMS larni filtrlash', b'0'),
('SMSInterval', '0', 'L', 'SMS lar orasidagi interval (sekund)', b'0'),
('SMSMatn1', '%manzil ga %minvaqt minutda %avto boryapti. Haydovchi telefoni: %htelefon Bot: http://t.me/zamintaxibot', 'S', 'Buyurtma qabul qilingandagi SMS matni', b'0'),
('SMSMatn2', '%manzil ga %avto keldi. Haydovchi telefoni: %htelefon Mobil ilova: https://bit.ly/2VPLQTu', 'S', 'Haydovchi yetib borgandagi SMS matni', b'0'),
('SMSMatn3', 'Hurmatli mijoz! Sizga boshqa mashina boryapti. Noqulaylik uchun uzr!', 'S', 'Buyurtma bekor qilingandagi SMS matni', b'0'),
('SMSMatn4', 'Endi mobil ilovamiz orqali buyurtma berishingiz mumkin.', 'S', 'Buyurtma yopilgandagi SMS matni', b'0'),
('SMSPaketLimit', '0', 'E', 'SMS paket limiti (ogohlantirish uchun)', b'0'),
('SMSPaketShablon', 'Qoldiq {[0-9]*}/[0-9]*SMS', 'S', 'SMS paket formati', b'0'),
('SMSPaketUlash', '*110*151#', 'S', 'SMS paketni ulash buyrug\'i', b'0'),
('SMSPaketUssd', '*100#', 'S', 'SMS paket sotib olish buyrug\'i', b'0'),
('SMSPaketUzish', '*110*150#', 'S', 'SMS paketni uzish buyrug\'i', b'0'),
('SMSRegister', 'BARAKA TOP: Tasdiqlash kodi - %kod', 'S', 'Mijoz dasturi uchun registratsiya SMS matni', b'0'),
('SMSSmart', '1', 'B', '\"Aqlli\" SMS jo\'natish', b'0'),
('SMSUsul', 'USB модем орқали', 'C:#0;Контент-провайдер орқали|#1;USB модем орқали', 'SMS larni jo\'natish usuli', b'0'),
('SMSVaqt', '5', 'L', 'SMS larni avtomatik tekshirish vaqti', b'0'),
('StateColor0', '&HFFFFFF&', 'S', 'Qabul qilinmagan buyurtma rangi', b'0'),
('StateColor1', '&H00FFFF&', 'S', 'Qabul qilingan buyurtma rangi', b'0'),
('StateColor2', '&H00FF00&', 'S', 'Bajarilayotgan buyurtma rangi', b'0'),
('StateColor3', '&HC0C0FF&', 'S', 'Bekor qilingan buyurtma rangi', b'0'),
('StateColor4', '&HFFC0C0&', 'S', 'Tugatilgan buyurtma rangi', b'0'),
('StateColor5', '&H0000FF&', 'S', 'Dostavkali buyurtma rangi', b'0'),
('StateColor9', '&H277FFF&', 'S', 'Tasdiqlanmagan buyurtma rangi', b'0');

-- --------------------------------------------------------

--
-- Структура таблицы `config_c`
--

CREATE TABLE `config_c` (
  `name` varchar(50) NOT NULL,
  `value` varchar(500) DEFAULT NULL,
  `data_type` varchar(500) DEFAULT NULL,
  `description` varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `config_c`
--

INSERT INTO `config_c` (`name`, `value`, `data_type`, `description`) VALUES
('CallCenter', '+998974164400', 'S', 'Call-markaz raqami'),
('CallerNumber', '+998996909707', 'S', 'Qo\'ng\'iroq qiluvchi nomer'),
('CancelOrder', '1', 'B', 'Bajarilayotgan buyurtmani bekor qilish imkoniyati'),
('DialMode', '1', 'L', 'Telefon raqamlariga qo\'ng\'iroq qilish usuli: 0 - raqam terish oynasini ochish, 1 - to\'g\'ridan-to\'g\'ri qo\'ng\'iroq qilish'),
('GPSForceOn', '1', 'B', 'GPS yoqilmasa dasturdan chiqish'),
('GPSRequestDistance', '10', 'L', 'GPS ma\'lumotlarini o\'qish oralig\'i (metr)'),
('GPSRequestTime', '5000', 'L', 'GPS ma\'lumotlarini o\'qish oralig\'i (millisekund)'),
('ManualRefresh', '1', 'B', 'Haydovchilar buyurtmalar ro\'yxatini yangilay olish imkoniyati'),
('NewProductLifeTime', '60', 'L', 'Yangi qo\'shilgan mahsulotning \"yangi\"ligi qancha soatgacha ko\'rinishi'),
('OperatorPhone', '+998974194400', 'S', 'Dispetcher telefon raqami'),
('RegionSelectMode', '2', 'L', 'Joriy hududni tanlash turi: [0] - yo\'q, [1] - ruchnoy, [2] - avtomatik'),
('SMSSender', '+998974194400', 'S', 'SMS jo\'natuvchi nomer'),
('UniversalCart', '1', 'B', 'Universal savat');

-- --------------------------------------------------------

--
-- Структура таблицы `config_p`
--

CREATE TABLE `config_p` (
  `name` varchar(50) NOT NULL,
  `value` varchar(500) DEFAULT NULL,
  `data_type` varchar(500) DEFAULT NULL,
  `description` varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `config_p`
--

INSERT INTO `config_p` (`name`, `value`, `data_type`, `description`) VALUES
('ArrivalTimes', '2,3,4,5,6,7', 'S', 'Yetib borish vaqtlari ro\'yxati'),
('Background', '', 'S', 'Buyurtmalar oynasi orqa fonidagi rasm manzili'),
('CallerNumber', '+998996909707', 'S', 'Qo\'ng\'iroq qiluvchi nomer'),
('CancelOrder', '1', 'B', 'Bajarilayotgan buyurtmani bekor qilish imkoniyati'),
('DialMode', '1', 'L', 'Telefon raqamlariga qo\'ng\'iroq qilish usuli: 0 - raqam terish oynasini ochish, 1 - to\'g\'ridan-to\'g\'ri qo\'ng\'iroq qilish'),
('FromRoad', '1', 'B', 'Yo\'lovchi olishga ruhsat'),
('GPSForceOn', '1', 'B', 'GPS yoqilmasa dasturdan chiqish'),
('GPSRequestDistance', '10', 'L', 'GPS ma\'lumotlarini o\'qish oralig\'i (metr)'),
('GPSRequestTime', '5000', 'L', 'GPS ma\'lumotlarini o\'qish oralig\'i (millisekund)'),
('ManualRefresh', '1', 'B', 'Haydovchilar buyurtmalar ro\'yxatini yangilay olish imkoniyati'),
('OperatorPhone', '+998974194400', 'S', 'Dispetcher telefon raqami'),
('RegionInfo', '2', 'L', 'Hududlar oynasida ko\'rinadigan qo\'shimcha ma\'lumotlar: [1] - mashinalar soni; [2] - buyurtma turlari'),
('RegionInfoAlignCount', '1', 'L', 'Hududlar oynasida buyurtmalar sonini tekislash: 0 - chap tomon, 1 - markaz, 2 - o\'ng tomon'),
('RegionInfoAlignIcons', '1', 'L', 'Hududlar oynasida buyurtmalar turi ikonkalarini tekislash: 0 - chap tomon, 1 - markaz, 2 - o\'ng tomon'),
('RegionInfoAlignName', '1', 'L', 'Hududlar oynasida hudud nomlarini tekislash: 0 - chap tomon, 1 - markaz, 2 - o\'ng tomon'),
('RegionSelectMode', '2', 'L', 'Joriy hududni tanlash turi: [0] - yo\'q, [1] - ruchnoy, [2] - avtomatik'),
('RegionShowAll', '0', 'B', 'Buyurtma yo\'q hududlarni ham ko\'rsatish'),
('RoundSum', '500', 'E', 'Buyurtma summasini yaxlitlash qiymati'),
('RoundSumType', '1', 'L', 'Buyurtma summasini yaxlitlash turi: 0 - yo\'q, 1 - yuqoriga, 2 - pastga, 3 - avto'),
('SelectArrivalTime', '1', 'B', 'Haydovchi yetib borish vaqtini tanlasin'),
('Services', '3', 'L', 'Mavjud qo\'shimcha hizmatlar: [1] - yukxona, [2] - ortiqcha yuk, [3] - sigaret, [4] - yomon havo, [5] - internet, [6] - yetkazma'),
('ShowClientInfo', '0', 'B', 'Haydovchilar buyurtmalar oynasida mijoz ma\'lumotlarini ko\'rib turishi'),
('SMSSender', '+998974194400', 'S', 'SMS jo\'natuvchi nomer'),
('TimerMode', '0', 'L', 'Buyurtma uchun vaqt taymeri turi: 0 - doimiy, 1 - faqat Kutish tugmasi orqali'),
('WelcomeMsg', '0.15', 'E', 'Mijozlar uchun \"Oq yo\'l\" habarini necha kilometr yurgandan keyin berilsin (0-habar eshitilmaydi)');

-- --------------------------------------------------------

--
-- Структура таблицы `counter`
--

CREATE TABLE `counter` (
  `id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `department`
--

CREATE TABLE `department` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `comments` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `department`
--

INSERT INTO `department` (`id`, `name`, `comments`) VALUES
(1, 'ZAMIN', ''),
(23, 'ЯКШАНБА С', ''),
(24, 'ZAMIN 4', ''),
(25, 'ЯКШАНБА О', ''),
(26, 'ZAMIN 6', ''),
(27, 'ЧОРШАНБА С', ''),
(28, 'ЧОРШАНБА О', ''),
(29, 'АЗИЯ', ''),
(31, '777', '');

-- --------------------------------------------------------

--
-- Структура таблицы `driver`
--

CREATE TABLE `driver` (
  `id` int(11) NOT NULL,
  `car_id` int(11) DEFAULT NULL,
  `no` int(11) DEFAULT NULL,
  `name` varchar(500) DEFAULT NULL,
  `phone` varchar(500) DEFAULT NULL,
  `birthday` date DEFAULT NULL,
  `nationality` varchar(20) DEFAULT NULL,
  `address` varchar(100) DEFAULT NULL,
  `password` varchar(10) DEFAULT NULL,
  `token` text DEFAULT NULL,
  `code` varchar(6) DEFAULT '',
  `device_id` varchar(32) DEFAULT NULL,
  `rating_status` int(11) DEFAULT 0,
  `rating_driver` int(11) DEFAULT 0,
  `rating_service` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `failed_jobs`
--

CREATE TABLE `failed_jobs` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Структура таблицы `message`
--

CREATE TABLE `message` (
  `id` int(11) NOT NULL,
  `msg` varchar(256) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `type` int(11) DEFAULT NULL,
  `car_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `message`
--

INSERT INTO `message` (`id`, `msg`, `date_created`, `type`, `car_id`) VALUES
(1, 'ыаываываыв', '2019-03-05 03:51:38', 0, 0),
(2, 'тест', '2019-03-05 03:51:52', 0, 0),
(3, 'SOS: [40.54002533, 70.94278402]', '2019-03-05 11:34:44', 1, 2),
(4, 'SOS: [40.54002533, 70.94278402]', '2019-03-05 11:34:52', 1, 2),
(5, 'SOS: [40.54002533, 70.94278402]', '2019-03-05 11:35:05', 1, 2),
(6, 'SOS: [40.54002533, 70.94278402]', '2019-03-05 11:35:17', 1, 2),
(7, 'SOS: [40.54002533, 70.94278402]', '2019-03-05 11:35:32', 1, 2),
(8, 'SOS: [40.54001763, 70.94291913]', '2019-03-05 11:35:52', 1, 2),
(9, 'SOS: [40.53988532, 70.94348175]', '2019-03-05 11:36:07', 1, 2),
(10, 'SOS: [40.53988532, 70.94348175]', '2019-03-05 11:36:18', 1, 2),
(11, 'SOS: [40.53988532, 70.94348175]', '2019-03-05 11:36:34', 1, 2),
(12, 'SOS: [40.53993321, 70.94337037]', '2019-03-05 11:38:07', 1, 2),
(13, 'SOS: [40.53993321, 70.94337037]', '2019-03-05 11:38:29', 1, 2),
(14, 'SOS: [40.54019571, 70.9437059]', '2019-03-05 11:44:21', 1, 4),
(15, 'SOS: [40.53983852, 70.94405252]', '2019-03-05 11:45:00', 1, 4),
(16, 'SOS: [40.53983852, 70.94405252]', '2019-03-05 11:45:13', 1, 4),
(17, 'SOS: [40.53983852, 70.94405252]', '2019-03-05 11:45:21', 1, 4),
(18, 'SOS: [40.53987392, 70.94335573]', '2019-03-05 11:45:36', 1, 2),
(19, 'SOS: [40.53987392, 70.94335573]', '2019-03-05 11:45:46', 1, 2),
(2299, 'SHOPIRLAR ZAYAFKALARGA YORDAM BERVORILAR', '2019-07-16 12:48:51', 0, 0),
(2300, 'XAMMA JOYDA RET EXTIYOT BULILAR', '2019-07-16 13:02:14', 0, 0),
(2301, 'ЗАЯВКАЛАРГА ЁРДАМ БЕРВОРИЛАР ХАР БИТТАЛАРИНГА ТЕЛЕФОН КИЛИШ ШАРТМИ', '2019-07-16 14:10:37', 0, 0),
(2302, 'SHOPIRLAR ZAYAFKALARGA YORDAM BERVORILAR', '2019-07-16 14:10:43', 0, 0),
(2303, 'DISHINI OLDIDA EXTIYOT BULILAR', '2019-07-16 15:20:35', 0, 0),
(2304, 'SHOPIRLAR ZAYAFKALARGA YORDAM BERVORILAR', '2019-07-16 20:05:24', 0, 0),
(2305, 'ЗАЯВКАЛАРГА ЁРДАМ БЕРВОРИЛАР ХАР БИТТАЛАРИНГА ТЕЛЕФОН КИЛИШ ШАРТМИ', '2019-07-16 20:05:30', 0, 0),
(2306, 'YURILAR ZAYAVKALRGA NIMA BULAYAPDI SILARGA', '2019-07-16 20:06:00', 0, 0),
(2307, 'SOS: [40.53992487, 70.94338989]', '2019-07-16 20:17:48', 1, 1091),
(2308, 'YURILAR ZAYAVKALRGA NIMA BULAYAPDI SILARGA', '2019-07-16 21:16:10', 0, 0),
(2309, '20-МАКТАБ ЁНИДА РЕТ', '2019-07-16 21:56:17', 0, 0),
(2310, 'SHOPIRLAR ZAYAFKALARGA YORDAM BERVORILAR', '2019-07-16 22:09:22', 0, 0),
(2311, 'SOS: [40.52988, 70.933436666667]', '2019-07-16 23:21:07', 1, 1025),
(2312, 'ШЕТТАМИСЛАР ШОПИРЛАР ЮРИЛАР ЗАЯВКАЛАРГА', '2019-07-17 00:26:22', 0, 0),
(2313, 'SOS: [40.539953070693, 70.944057209417]', '2019-07-17 00:58:58', 1, 366),
(2314, 'НЕФТ БАЗАГА ЮРВОРИЛАР ШОПИРЛАР', '2019-07-17 03:43:40', 0, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `message_template`
--

CREATE TABLE `message_template` (
  `id` int(11) NOT NULL,
  `text` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `message_template`
--

INSERT INTO `message_template` (`id`, `text`) VALUES
(1, 'Ҳурматли ҳайдовчилар! Буюртмаларни олинглар!');

-- --------------------------------------------------------

--
-- Структура таблицы `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Дамп данных таблицы `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(5, '2014_10_12_000000_create_users_table', 1),
(6, '2014_10_12_100000_create_password_resets_table', 1),
(7, '2019_08_19_000000_create_failed_jobs_table', 1),
(8, '2019_12_14_000001_create_personal_access_tokens_table', 1);

-- --------------------------------------------------------

--
-- Структура таблицы `nationality`
--

CREATE TABLE `nationality` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `nationality`
--

INSERT INTO `nationality` (`id`, `name`) VALUES
(6, 'рус'),
(7, 'татар'),
(2, 'тожик'),
(5, 'туркман'),
(1, 'ўзбек'),
(3, 'қирғиз'),
(4, 'қозоқ');

-- --------------------------------------------------------

--
-- Структура таблицы `offered_sums`
--

CREATE TABLE `offered_sums` (
  `id` int(11) NOT NULL,
  `sum` int(11) DEFAULT NULL,
  `order` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `offered_sums`
--

INSERT INTO `offered_sums` (`id`, `sum`, `order`) VALUES
(1, 3000, NULL),
(2, 3500, NULL),
(3, 4000, NULL),
(4, 4500, NULL),
(5, 5000, NULL),
(6, 5500, NULL),
(7, 6000, NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `orders`
--

CREATE TABLE `orders` (
  `id` int(11) NOT NULL,
  `phone` varchar(20) DEFAULT NULL COMMENT 'Mijoz telefon raqami',
  `from` varchar(100) DEFAULT NULL COMMENT 'Qayerdan',
  `to` varchar(100) DEFAULT NULL COMMENT 'Qayerga',
  `region_id` int(11) DEFAULT NULL COMMENT 'Hudud ID si',
  `region_id2` int(11) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL COMMENT 'Mijoz ID si',
  `group_id` int(11) DEFAULT 0 COMMENT 'Mijoz guruhi ID si (korporativ mijozlar uchun)',
  `status` int(11) DEFAULT 0 COMMENT 'Buyurtma holati: 0 - yangi, 1 - olingan, 2 - bajarilmoqda, 3 - bekor qilingan, 4 - tugatilgan, -1 - tasdiqlanmagan',
  `date_created` datetime DEFAULT NULL COMMENT 'Buyurtma qo''shilgan vaqt',
  `date_accepted` datetime DEFAULT NULL COMMENT 'Buyurtma haydovchi tomonidan olingan vaqt',
  `date_started` datetime DEFAULT NULL COMMENT 'Buyurtma bajarilishi boshlangan vaqt',
  `date_closed` datetime DEFAULT NULL COMMENT 'Buyurtma tugatilgan vaqt',
  `driver_id` int(11) DEFAULT NULL COMMENT 'Haydovchi ID si',
  `department_id` int(11) DEFAULT 0 COMMENT 'Filial ID si',
  `user_id` int(11) DEFAULT NULL COMMENT 'Buyurtmani qo''shgan dispetcher ID si',
  `arrival_time` int(11) DEFAULT 0 COMMENT 'Buyurtmaga haydovchining yetib borish vaqti',
  `platform` int(11) DEFAULT 0 COMMENT 'Buyurtma qayerdan berilganligi: 0 - telefon orqali, 1 - Android dastur orqali, 2 - Telegram bot orqali, 3 - iOS dastur orqali, 4 - Website orqali, 5 - IP telefon(SIP)',
  `order_type` int(11) DEFAULT 1 COMMENT 'Buyurtma turi: 1 - Oddiy, 2 - Tezkor, 3 - Komfort, 4 - Yetkazma, 5 - Yo''lovchi.  Tarif ID si',
  `counter1` int(11) DEFAULT 0,
  `counter2` int(11) DEFAULT 0,
  `distance` float DEFAULT 0,
  `distance_out` float DEFAULT 0,
  `sum` float DEFAULT 0,
  `sum_delivery` float DEFAULT 0,
  `bonus` int(11) DEFAULT 0 COMMENT 'Bonus ',
  `sum_bonus` float DEFAULT 0 COMMENT 'Bonus summasi',
  `sum_services` float DEFAULT 0 COMMENT 'Qo''shimcha hizmatlar summasi',
  `services` int(11) DEFAULT 0 COMMENT 'Qo''shimcha hizmatlar (flag)',
  `comments` varchar(50) NOT NULL DEFAULT '',
  `latitude` double DEFAULT 0,
  `longitude` double DEFAULT 0,
  `ext1` int(11) DEFAULT 0,
  `sum_offered` float DEFAULT 0,
  `user_id_delete` int(11) DEFAULT NULL,
  `user_id_modify` int(11) DEFAULT NULL,
  `flags` int(11) DEFAULT 0,
  `rating_status` int(11) DEFAULT 0,
  `rating_driver` int(11) DEFAULT 0,
  `rating_service` int(11) DEFAULT 0,
  `version` int(11) DEFAULT 0,
  `partner_id` int(11) DEFAULT 0,
  `partner_latitude` double DEFAULT NULL,
  `partner_longitude` double DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `orders`
--

INSERT INTO `orders` (`id`, `phone`, `from`, `to`, `region_id`, `region_id2`, `client_id`, `group_id`, `status`, `date_created`, `date_accepted`, `date_started`, `date_closed`, `driver_id`, `department_id`, `user_id`, `arrival_time`, `platform`, `order_type`, `counter1`, `counter2`, `distance`, `distance_out`, `sum`, `sum_delivery`, `bonus`, `sum_bonus`, `sum_services`, `services`, `comments`, `latitude`, `longitude`, `ext1`, `sum_offered`, `user_id_delete`, `user_id_modify`, `flags`, `rating_status`, `rating_driver`, `rating_service`, `version`, `partner_id`, `partner_latitude`, `partner_longitude`) VALUES
(1, '+998916848100', 'BarakaTop', 'А. Икромов 61', 1, 2, 102802, 0, 3, '2019-07-20 12:48:49', NULL, NULL, '2019-07-20 16:34:42', NULL, 0, 0, 0, 1, 4, 1, 0, 0, 0, 0, 58000, 0, 0, 0, 0, '', 40.545110494941, 70.972634985655, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(2, '+998916848100', 'BarakaTop', 'Gkdhro', 1, 7, 102802, 0, 3, '2019-07-20 16:09:31', NULL, NULL, '2019-07-20 16:34:40', NULL, 0, 0, 0, 1, 4, 2, 0, 0, 0, 0, 20000, 0, 0, 0, 0, '', 40.530924576546, 70.952186302577, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(3, '+998916848100', 'BarakaTop', 'test', 1, 7, 102802, 0, 3, '2019-07-20 16:34:17', NULL, NULL, '2019-07-20 16:34:38', NULL, 0, 0, 0, 1, 4, 3, 0, 0, 0, 0, 10000, 0, 0, 0, 0, '', 40.530946271123, 70.952257765466, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(4, '+998916848100', 'BarakaTop', 'BarakaTop', 1, 1, 102802, 0, 3, '2019-07-20 16:34:54', NULL, NULL, '2019-07-20 17:40:33', NULL, 0, 0, 0, 1, 4, 1, 0, 0, 0, 0, 10000, 0, 0, 0, 0, '', 40.530818725159, 70.952320458004, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(5, '+998916848100', 'BarakaTop', 'BarakaTop', 1, 1, 102802, 0, 4, '2019-07-20 17:40:56', NULL, NULL, '2019-07-20 17:42:27', NULL, 0, 0, 0, 1, 4, 1, 0, 0, 0, 0, 22500, 0, 0, 0, 0, '', 40.531013620639, 70.952269567056, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(6, '+998916848100', 'BarakaTop', 'BarakaTop', 1, 1, 102802, 0, 4, '2019-07-20 17:47:49', NULL, NULL, '2019-07-20 17:48:41', NULL, 0, 0, 0, 1, 4, 2, 0, 0, 0, 0, 2500, 0, 0, 0, 0, '', 40.530966818168, 70.952153231928, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(7, '+998916848100', 'BarakaTop', 'BarakaTop', 1, 1, 102802, 0, 4, '2019-07-20 17:58:57', NULL, NULL, '2019-07-20 17:59:45', NULL, 0, 0, 0, 1, 4, 3, 0, 0, 0, 0, 2500, 0, 0, 0, 0, '', 40.530933401502, 70.952202516245, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(8, '+998916848100', 'BarakaTop', 'BarakaTop', 1, 1, 102802, 0, 4, '2019-07-20 18:10:43', NULL, NULL, '2019-07-20 18:12:01', NULL, 0, 0, 0, 1, 4, 4, 0, 0, 0, 0, 2500, 0, 0, 0, 0, '', 40.530870287538, 70.952223735473, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL),
(11466, '+998912008070', 'Озик овкатлар', 'Unnamed Road, Қўқон, Фирокий37Узбекистан', 1, 0, 102970, 0, -2, '2021-09-05 11:19:31', NULL, NULL, NULL, NULL, 0, 0, 0, 1, 4, 81, 0, 0, 0, 0, 154000, 0, 0, 0, 0, '', 40.55780287832, 70.959086716175, 0, 0, NULL, NULL, 0, 0, 0, 0, 0, 1, NULL, NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `order_details`
--

CREATE TABLE `order_details` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `price` double NOT NULL,
  `additional` varchar(500) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `order_details`
--

INSERT INTO `order_details` (`id`, `order_id`, `product_id`, `quantity`, `price`, `additional`) VALUES
(1, 1, 68, 1, 14000, NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `partner`
--

CREATE TABLE `partner` (
  `id` int(11) NOT NULL COMMENT '1-admin, 2-user',
  `name` varchar(50) COLLATE utf8_bin NOT NULL,
  `image` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `login` varchar(50) COLLATE utf8_bin DEFAULT NULL,
  `password` varchar(50) COLLATE utf8_bin DEFAULT NULL,
  `region_id` int(11) DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `active` int(11) DEFAULT 1,
  `comments` varchar(200) COLLATE utf8_bin DEFAULT NULL,
  `background` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `open_time` time DEFAULT NULL,
  `close_time` time DEFAULT NULL,
  `rating` float DEFAULT NULL,
  `price` float DEFAULT NULL,
  `user_group` int(11) DEFAULT NULL COMMENT '1-super admin, 2-partner admin, 3-operator',
  `closed` int(11) DEFAULT 0 COMMENT '0-ochiq, 1-yopiq',
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `sum_min` float DEFAULT 0,
  `sum_delivery` float DEFAULT 0 COMMENT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `partner`
--

INSERT INTO `partner` (`id`, `name`, `image`, `login`, `password`, `region_id`, `phone`, `active`, `comments`, `background`, `group_id`, `open_time`, `close_time`, `rating`, `price`, `user_group`, `closed`, `latitude`, `longitude`, `sum_min`, `sum_delivery`) VALUES
(1, 'Озик овкатлар', '/images/partner_1_1607914496.png', 'baraka', '123', 1, '+998974194400', 1, 'Озиқ-овқат маҳсулотлари', '/images/partner_1_1607914496.png', 3, '07:00:00', '19:00:00', 4.5, 5000, 3, 1, 40.52922047818758, 70.95312383025885, 50000, 0),
(3, 'Китоблар', '/images/partner_3.png', 'boshqaruvchi', '5252', 3, '+998974194400', 1, '', '/images/partner_3.png', 3, '07:00:00', '21:00:00', NULL, 0, NULL, 1, NULL, NULL, 0, 0),
(5, 'Канцелария моллари', '/images/partner_5.png', 'Bshqaruvchi', '5252', 5, '+998974194400', 1, '', '/images/partner_5.png', 3, NULL, NULL, NULL, 0, NULL, 1, NULL, NULL, 0, 0),
(6, 'Симкарталар', '/images/partner_6.png', 'boshqaruvchi', '5252', 6, '+998974194400', 1, '', '/images/partner_6.png', 3, '07:00:00', '21:00:00', NULL, 0, NULL, 1, NULL, NULL, 0, 0),
(8, 'Аёллар учун', '/images/partner_8.png', 'baraka', '123', 8, '+998974194400', 1, '', '/images/partner_8.png', 3, '07:00:00', '19:30:00', NULL, 0, NULL, 1, NULL, NULL, 0, 0),
(9, 'Электроника', '/images/partner_9.png', 'Barakatop', '5252', 9, '+998974194400', 1, '', '/images/partner_9.png', 3, '07:00:00', '19:00:00', NULL, 0, NULL, 1, NULL, NULL, 0, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `partner_group`
--

CREATE TABLE `partner_group` (
  `id` int(11) NOT NULL,
  `name` varchar(50) COLLATE utf8_bin DEFAULT NULL,
  `image` varchar(100) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `partner_group`
--

INSERT INTO `partner_group` (`id`, `name`, `image`) VALUES
(1, 'Фастфуд', 'images/partners/groups/10.jpg'),
(2, 'Ресторан', 'images/partners/groups/11.jpg'),
(3, 'Магазин', 'images/partners/groups/12.jpg'),
(4, 'Аптека', 'images/partners/groups/13.jpg');

-- --------------------------------------------------------

--
-- Структура таблицы `password_resets`
--

CREATE TABLE `password_resets` (
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Структура таблицы `payment_type`
--

CREATE TABLE `payment_type` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `sum` double DEFAULT NULL COMMENT 'Balli to''lov uchun 1 ball narxi, Muhlatli to''lov uchun 1 kunlik to''lov narxi',
  `type` int(11) DEFAULT NULL COMMENT '0-Balli to''lov; 1-Muhlatli to''lov; 2-To''lovsiz',
  `daily` int(11) DEFAULT 0,
  `maximum` int(11) DEFAULT 0,
  `minus` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `payment_type`
--

INSERT INTO `payment_type` (`id`, `name`, `sum`, `type`, `daily`, `maximum`, `minus`) VALUES
(1, 'Шахсий машина (сариқ)', 300, 0, 5, 5, 1),
(2, 'Шахсий машина (оқ)', 500, 0, 5, 4, 1),
(3, 'Лицензияли машина', 18000, 1, 0, 0, 0),
(4, 'Компания машинаси (1 ҳайдовчи)', 88000, 1, 0, 0, 0),
(5, 'Компания машинаси (2 ҳайдовчи)', 100000, 1, 0, 0, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `personal_access_tokens`
--

CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `tokenable_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Структура таблицы `photo`
--

CREATE TABLE `photo` (
  `id` int(11) NOT NULL,
  `driver_id` int(11) DEFAULT NULL,
  `car_id` int(11) DEFAULT NULL,
  `type` int(11) DEFAULT NULL,
  `photo` blob DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `place`
--

CREATE TABLE `place` (
  `id` int(11) NOT NULL,
  `name` varchar(100) COLLATE utf8_bin DEFAULT NULL,
  `type_id` int(11) DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `author` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `comment` varchar(100) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `place`
--

INSERT INTO `place` (`id`, `name`, `type_id`, `latitude`, `longitude`, `phone`, `author`, `comment`) VALUES
(1, 'А.Икромов', 1, 40.545061253943, 70.972618544474, NULL, '+998916848100', ''),
(2, 'А.Икромов 61', 2, 40.545153873973, 70.972594153136, NULL, '+998916848100', ''),
(4, 'А.Икромов 116', 2, 40.545193478465, 70.972576970235, NULL, '+998916848100', ''),
(5, 'А.Икромов', 2, 40.544715709984, 70.971675161272, NULL, '+998916848100', ''),
(6, 'Ароба такси офиси', 19, 40.536921545863, 70.961732715368, NULL, '+998916848100', ''),
(7, 'Имзо', 19, 40.536963455379, 70.962041504681, NULL, '+998916848100', ''),
(8, 'А.Навоий 113', 2, 40.536954319105, 70.962123479694, NULL, '+998916848100', ''),
(9, 'А.Навоий', 1, 40.536969699897, 70.962123563513, NULL, '+998916848100', ''),
(10, 'А.Навоий', 1, 40.537060098723, 70.963343381882, NULL, '+998916848100', ''),
(11, 'EuroMed диагностика', 13, 40.537131638266, 70.964017622173, NULL, '+998916848100', ''),
(12, 'А.Навоий', 1, 40.537173966877, 70.964388521388, NULL, '+998916848100', ''),
(13, 'А.Навоий', 1, 40.537315243855, 70.965379094705, NULL, '+998916848100', ''),
(14, 'Assalom', 3, 40.537419766188, 70.965985944495, NULL, '+998916848100', ''),
(15, 'Центр обоев', 3, 40.537432674319, 70.966063728556, NULL, '+998916848100', ''),
(16, 'Akfa universal', 3, 40.537454090081, 70.966342426836, NULL, '+998916848100', ''),
(17, 'Osiyo мебел маркази', 3, 40.537483049557, 70.966513417661, NULL, '+998916848100', ''),
(18, 'Imzo', 3, 40.537507105619, 70.966593213379, NULL, '+998916848100', ''),
(19, 'А. Навоий', 1, 40.537517708726, 70.966666052118, NULL, '+998916848100', ''),
(20, 'Olmos мехмонхона', 17, 40.537529066205, 70.966730425134, NULL, '+998916848100', ''),
(21, 'А. Навоий', 1, 40.537639162503, 70.967564256862, NULL, '+998916848100', ''),
(22, 'Konizar', 3, 40.53768358659, 70.967822084203, NULL, '+998916848100', ''),
(23, 'А. Навоий', 1, 40.537776332349, 70.968518285081, NULL, '+998916848100', ''),
(24, 'O\'zbegim', 3, 40.53778660018, 70.968556087464, NULL, '+998916848100', ''),
(25, 'Norin', 5, 40.537892044522, 70.969122368842, NULL, '+998916848100', ''),
(26, 'А. Навоий', 1, 40.537951136939, 70.969383632764, NULL, '+998916848100', ''),
(27, 'Mukammal market', 3, 40.537987221032, 70.969609441236, NULL, '+998916848100', ''),
(28, 'May market', 3, 40.538041912951, 70.969971958548, NULL, '+998916848100', ''),
(29, 'А. Навоий', 1, 40.538143669255, 70.970312515274, NULL, '+998916848100', ''),
(30, 'А. Навоий', 1, 40.538374213502, 70.97113863565, NULL, '+998916848100', ''),
(31, 'Стоматалогия ', 13, 40.538538917899, 70.971655799076, NULL, '+998916848100', ''),
(32, 'А. Навоий', 1, 40.538645787165, 70.971968946978, NULL, '+998916848100', ''),
(33, 'Ташриф', 17, 40.538670304231, 70.972067099065, NULL, '+998916848100', ''),
(34, 'SAG gilamlar', 3, 40.53872579243, 70.972202382982, NULL, '+998916848100', ''),
(35, 'Vinograd', 3, 40.538822393864, 70.972517458722, NULL, '+998916848100', ''),
(36, 'А. Навоий', 1, 40.538955708034, 70.972863128409, NULL, '+998916848100', ''),
(37, 'Center Elektrolayt', 3, 40.539044011384, 70.973159680143, NULL, '+998916848100', ''),
(38, 'Ipoteka', 8, 40.539089064114, 70.973261101171, NULL, '+998916848100', ''),
(39, 'Навоий туйхона', 16, 40.53976116702, 70.973207205534, NULL, '+998916848100', ''),
(40, 'Навоий бозорча', 16, 40.540088857524, 70.973054068163, NULL, '+998916848100', ''),
(41, 'Lazzat ошхона', 5, 40.540585778654, 70.972611838952, NULL, '+998916848100', ''),
(42, 'Nihol', 3, 40.540651492774, 70.972531791776, NULL, '+998916848100', ''),
(43, 'Marvarid market', 3, 40.54111585021, 70.972472531721, NULL, '+998916848100', ''),
(44, 'Olimpia спорт магазин', 3, 40.541393542662, 70.972405392677, NULL, '+998916848100', ''),
(45, 'Al-Kabab', 5, 40.541896582581, 70.972049748525, NULL, '+998916848100', ''),
(46, 'Qurilish kollej', 5, 40.542553095147, 70.971485730261, NULL, '+998916848100', ''),
(47, 'Konstitutsiya ko\'cha', 1, 40.543542956002, 70.970619460568, NULL, '+998916848100', ''),
(48, 'A. Ikromov ko\'cha', 1, 40.544028687291, 70.970264486969, NULL, '+998916848100', ''),
(49, '1-Mashrab ko\'cha', 1, 40.544358096085, 70.970881395042, NULL, '+998916848100', ''),
(50, '2-Mashrab ko\'cha', 1, 40.544600668363, 70.97156024538, NULL, '+998916848100', ''),
(51, '3-Mashrab ko\'cha', 1, 40.544914905913, 70.972290895879, NULL, '+998916848100', ''),
(52, 'А. Икромов 114', 2, 40.544978566468, 70.972499186173, NULL, '+998916848100', ''),
(53, 'А. Икромов 63', 2, 40.545226545073, 70.972784589976, NULL, '+998916848100', ''),
(54, '4-Mashrab ko\'cha', 1, 40.545300138183, 70.972968237475, NULL, '+998916848100', ''),
(55, 'Mashrab 122', 2, 40.545430602506, 70.972924232483, NULL, '+998916848100', ''),
(56, 'Mashrab 120', 2, 40.545554948039, 70.972870253026, NULL, '+998916848100', ''),
(57, 'Mashrab 118', 2, 40.545675437897, 70.972777716815, NULL, '+998916848100', ''),
(288, 'mendeleyev 6 dom', 2, 40.5274118, 70.9412797, NULL, '+998903060772', '');

-- --------------------------------------------------------

--
-- Структура таблицы `place_type`
--

CREATE TABLE `place_type` (
  `id` int(11) NOT NULL,
  `name` varchar(100) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `place_type`
--

INSERT INTO `place_type` (`id`, `name`) VALUES
(1, 'кўча'),
(2, 'уй'),
(3, 'магазин'),
(4, 'аптека'),
(5, 'ошхона'),
(6, 'бозор'),
(7, 'салон'),
(8, 'банк'),
(9, 'чойхона'),
(10, 'устахона'),
(11, 'мактаб'),
(12, 'боғча'),
(13, 'шифохона'),
(14, 'коллеж'),
(15, 'лицей'),
(16, 'тўйхона'),
(17, 'меҳмонхона'),
(18, 'масжид'),
(19, 'ташкилот'),
(20, 'институт'),
(21, 'ҳовли'),
(22, 'автовокзал'),
(23, 'автосалон'),
(24, 'мойка'),
(25, 'ҳаммом'),
(26, 'бензин заправка'),
(27, 'метан заправка'),
(28, 'пропан заправка'),
(29, 'стадион'),
(30, 'истироҳат боғи'),
(31, 'бекат'),
(32, 'вокзал'),
(33, 'кафе');

-- --------------------------------------------------------

--
-- Структура таблицы `plate_pattern`
--

CREATE TABLE `plate_pattern` (
  `id` int(11) NOT NULL,
  `text` varchar(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `plate_pattern`
--

INSERT INTO `plate_pattern` (`id`, `text`) VALUES
(1, 'DD X DDD XX'),
(2, 'DD DDD XXX');

-- --------------------------------------------------------

--
-- Структура таблицы `products`
--

CREATE TABLE `products` (
  `id` int(11) NOT NULL,
  `name` varchar(50) COLLATE utf8_bin NOT NULL,
  `price` double NOT NULL DEFAULT 0,
  `image` varchar(300) COLLATE utf8_bin DEFAULT '',
  `partner_id` int(11) DEFAULT 0,
  `group` int(11) DEFAULT 0,
  `parent_id` int(11) DEFAULT 0,
  `type` int(11) DEFAULT 0,
  `comments` varchar(200) COLLATE utf8_bin DEFAULT NULL,
  `active` int(11) NOT NULL DEFAULT 1,
  `date_created` datetime DEFAULT NULL,
  `options` text CHARACTER SET utf8 DEFAULT NULL,
  `rating` double DEFAULT 0,
  `status` int(11) DEFAULT 1,
  `discount` float DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `products`
--

INSERT INTO `products` (`id`, `name`, `price`, `image`, `partner_id`, `group`, `parent_id`, `type`, `comments`, `active`, `date_created`, `options`, `rating`, `status`, `discount`) VALUES
(1191, '1/Сабзавотлар', 0, '/images/product_1191_1607884406.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1192, '2/Колбаса маҳсулотлари', 0, '/images/product_1192_1607884943.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1193, '3/Гушт маҳсулотлари', 0, '/images/product_1193_1617259504.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1194, '4/Сут маҳсулотлари', 0, '/images/product_1194_1617260983.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1195, 'Чап-чап нон', 2500, '/images/product_1195.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1196, 'Оби нон', 2500, '/images/product_1196.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1197, '5/Ун ва Макаронлар ', 0, '/images/product_1197_1617266234.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1198, '6/Дон маҳсулотлари', 0, '/images/product_1198_1607886306.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1199, '7/Туз ва Зираворлар', 0, '/images/product_1199_1617267240.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1200, '8/Кетчуп Майонез Соус', 0, '/images/product_1200_1617268397.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1201, '9/Ёг ва Сарёг маҳсулотлари', 0, '/images/product_1201_1617270735.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1210, '1/1- Бодринг ', 6000, '/images/product_1210.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1211, '1/2- Картошка янги', 5000, '/images/product_1211.png', 0, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 4, 1, 0),
(1212, '1/3- Пиёз ', 2000, '/images/product_1212.png', 0, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1213, '1/4- Сабзи кизил ', 9000, '/images/product_1213.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1214, '1/5- Шолгом янги', -5000, '/images/product_1214.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1216, '1/6- Булгор калампири (кук) 1 кг', 5000, '/images/product_1216.png', 1, 0, 1191, 0, '1 кг ', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1217, '1/7- Картошка1 кг', 4500, '', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1218, '1/8- Кашнич 1 бог', 1500, '/images/product_1218.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 5, 1, 0),
(1219, '1/9- Укроп 1 бог ', 1500, '/images/product_1219.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 5, 1, 0),
(1221, '1/10- Калампир 1 шт', 250, '/images/product_1221.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1222, '1/11- Кизилча 1 кг ', 6000, '/images/product_1222.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1225, '10/консервы', 0, '/images/product_1225_1617342591.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1226, '1/12- Карам 1 дона', 4000, '/images/product_1226.png', 1, 0, 1191, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1228, '11/Мевалар', 0, '/images/product_1228_1609070139.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1229, '18/1 Соca cola 1,5 л', 10000, '/images/product_1229.png', 1, 0, 2471, 0, '1.5 л', 1, NULL, NULL, 5, 1, 0),
(1230, '18/2 Fanta 1.5 л', 10000, '/images/product_1230.png', 1, 0, 2471, 0, ' 1.5 л', 1, NULL, NULL, 5, 1, 0),
(1231, '11/1 Олма сорт \"Крепсон\" 1 кг ', 39000, '/images/product_1231.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1232, '11/2 \"Нок\" 1кг', 29000, '/images/product_1232.png', 1, 0, 1228, 0, '1 кг', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 4.5, 1, 0),
(1233, '11/3- Шафтоли кизил 1кг', 25000, '/images/product_1233.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1234, '18/3 Sprite 1,5 л', 10000, '/images/product_1234.png', 1, 0, 2471, 0, '1.5 л', 1, NULL, NULL, 0, 1, 0),
(1236, '18/4 Dinay напиток 1л', 7000, '/images/product_1236.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1237, 'Банан', 22000, '/images/product_1237.png', 0, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 3.6666666666666665, 1, 0),
(1238, '18/5 Сочная Долина сок', 9000, '/images/product_1238.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1239, '18/6 Pepsi 1,5 л', 12000, '/images/product_1239.png', 1, 0, 2471, 0, '1.5 л', 1, NULL, NULL, 5, 1, 0),
(1240, '18/7 Nestle газированная 1,5 л', 3000, '/images/product_1240.png', 1, 0, 2471, 0, '1.5 л', 1, NULL, NULL, 0, 1, 0),
(1241, 'Узум (ризамат)', 16000, '', 0, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1242, '18/8 Nestle негазированная 1,5 л', 3000, '/images/product_1242.png', 1, 0, 2471, 0, '1,5 л', 1, NULL, NULL, 0, 1, 0),
(1243, '11/4 Узум 1кг', 20000, '/images/product_1243.png', 0, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1244, '18/9 Jesko сок', -6000, '/images/product_1244.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1245, '18/10 Bliss сок', 9000, '/images/product_1245.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1247, '9/1 Ariel aвтомат 3 кг', 53000, '/images/product_1247.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 4, 1, 0),
(1248, '9/2 Ariel aвтомат 5 кг', 100000, '/images/product_1248.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1249, '9/3 Ariel aвтомат 9 кг', 180000, '/images/product_1249.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 5, 1, 0),
(1250, '11/5- Ковун 1кг', 3000, '/images/product_1250.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(1251, '11/6 Тарвуз 1 кг  5 кг дан 9 кг гача', 1800, '/images/product_1251.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 5, 1, 0),
(1252, 'Киви', 15000, '/images/product_1252.png', 0, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1254, '11/7 Апельсин 1кг', 40000, '/images/product_1254.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1255, '11/8 Лимон 1кг', 48000, '/images/product_1255.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1256, '1/14- Булгор калампир (кизил) 1 кг', 4000, '/images/product_1256.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1258, '1/15- Райхон 1 бог', -1000, '/images/product_1258.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1260, '1/16- Кук пиёз 1 бог', 2000, '/images/product_1260.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 5, 1, 0),
(1261, '1/17- Карам (кизил) дона', -10000, '/images/product_1261.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1262, '18/11 Flesh UZB  500мл', 7500, '/images/product_1262.png', 1, 0, 2471, 0, '0.7 л', 1, NULL, NULL, 5, 1, 0),
(1263, '18/12 Flesh UZB  250мл', 5000, '/images/product_1263.png', 1, 0, 2471, 0, '0,25 л', 1, NULL, NULL, 0, 1, 0),
(1264, '3/1- Мол гушти 1 кг', 70000, '/images/product_1264.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1265, '3/2 Мол гушти (лахм) 1кг', 88000, '/images/product_1265.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1266, '3/3 Куй гушти 1кг', 80000, '/images/product_1266.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1267, '3/4- Мол гушти (кийма)', 88000, '/images/product_1267.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1269, '18/13 Pepsi 1 л', 9500, '/images/product_1269.png', 1, 0, 2471, 0, '1 л', 1, NULL, NULL, 0, 1, 0),
(1270, '3/5- Товук канот 1 кг', 40000, '/images/product_1270.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1271, '18/14 Pepsi 0.5 л ', 6000, '/images/product_1271.png', 1, 0, 2471, 0, '0,5 л', 1, NULL, NULL, 0, 1, 0),
(1272, '3/6- Товук сонча 1 кг', 40000, '/images/product_1272.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1273, '18/15 Coca cola 1 л', 9500, '/images/product_1273.png', 1, 0, 2471, 0, '1 л', 1, NULL, NULL, 0, 1, 0),
(1274, '3/7- Товук оёги ( акарачка )1кг', 35000, '/images/product_1274.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 4, 1, 0),
(1276, '18/17 Fanta 1 л', 9500, '/images/product_1276.png', 1, 0, 2471, 0, '1 л', 1, NULL, NULL, 0, 1, 0),
(1277, '18/18 Fanta 0.5 л', 6000, '/images/product_1277.png', 1, 0, 2471, 0, '0,5 л', 1, NULL, NULL, 0, 1, 0),
(1278, '3/8- Товук Броллер 1кг Саховат', 35000, '/images/product_1278.png', 1, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1279, 'Dena сок', 6500, '', 0, 0, 0, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1281, '2/2 \"Т/ота\"  (cервелат корона) копчёная колбаса', -49000, '/images/product_1281.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(1282, '18/19 Ark tea 1.5 л', 6000, '/images/product_1282.png', 1, 0, 2471, 0, '1,5 л', 1, NULL, NULL, 5, 1, 0),
(1283, 'Розметов п/к (капчоный)  Восточная 1 дона', 33000, '', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(1284, '2/3 \"Тухтаниёз ота\" егли (варёная колбаса) 1 кг	', -61000, '/images/product_1284.png', 1, 0, 1192, 0, 'егли', 1, NULL, NULL, 5, 1, 0),
(1285, '2/4 \"Тухтаниёз ота\" (сосиски) 1 пачка			', 11000, '/images/product_1285.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1287, '18/20 Dena сок шафтоли 1л', 9000, '/images/product_1287.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1288, '18/21 Hydrolife негазированная 0,5 л', 2000, '/images/product_1288.png', 1, 0, 2471, 0, '0,5 л', 1, NULL, NULL, 5, 1, 0),
(1290, '18/22 Hydrolife негазированная 1 л', 2500, '/images/product_1290.png', 1, 0, 2471, 0, '1 л', 1, NULL, NULL, 0, 1, 0),
(1292, '18/23 Hydrolife негазированная  1.5 л', 3500, '/images/product_1292.png', 1, 0, 2471, 0, '1.5', 1, NULL, NULL, 0, 1, 0),
(1293, '9/1 Ярко 2л	', 47000, '/images/product_1293.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1295, '9/2- Ярко 5л	', 120000, '/images/product_1295.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1296, '18/24 Hydrolife негазированная 10 л', 12000, '/images/product_1296.png', 1, 0, 2471, 0, '10 л', 1, NULL, NULL, 0, 1, 0),
(1297, '9/3-Затея 1 л', 28000, '/images/product_1297.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1298, 'Затея 5 л	', 55000, '', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(1299, '9/4 Затея 1.8 л', 46000, '/images/product_1299.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1300, '9/5 Затея 5 л	', 125000, '/images/product_1300.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 5, 1, 0),
(1301, 'Янтар 1л', 11000, '/images/product_1301.png', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(1302, '9/6 Янтаръ 2 л	', 47000, '/images/product_1302.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1303, '9/7 Янтаръ 3 л	', 70000, '/images/product_1303.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1304, '9/8 Янтаръ 5 л	', 120000, '/images/product_1304.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1305, '9/4 Tide автомат 1,5 кг', 32000, '/images/product_1305.png', 1, 0, 3825, 0, '1,5 кг', 1, NULL, NULL, 0, 1, 0),
(1306, '9/5 Tide автомат 2,5 КГ ', 46000, '/images/product_1306.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1307, '4/1 \"Nestle\" молоко 1% ', 9000, '/images/product_1307.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1308, '4/2 \"Nestle\" молоко 2%', 9500, '/images/product_1308.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1309, '9/6 Tide автомат 6 кг', 97000, '/images/product_1309.png', 1, 0, 3825, 0, '6 кг', 1, NULL, NULL, 0, 1, 0),
(1310, '4/3 \"Nestle\" молоко 3,2%', 10000, '/images/product_1310.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1311, '4/4 Сметана \"Даза\"  500мл 20%', -8000, '/images/product_1311_1618637805.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1312, '4/5 Сметана \"Садаф\"  500мл 20%', 7000, '/images/product_1312.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1313, '9/7 Persil автомат 3 кг', 55000, '/images/product_1313.png', 1, 0, 3825, 0, '3 кг', 1, NULL, NULL, 0, 1, 0),
(1314, '9/8 Persil автомат color 6 кг', 115000, '/images/product_1314.png', 1, 0, 3825, 0, '6 кг', 1, NULL, NULL, 0, 1, 0),
(1315, '4/6 Каймок  200гр', 7500, '/images/product_1315.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 4.5, 1, 0),
(1316, '9/10 Persil автомат color 9 кг', 179000, '/images/product_1316.png', 1, 0, 3825, 0, '9 кг', 1, NULL, NULL, 0, 1, 0),
(1317, '4/7 Сметана \"Садаф\"  500мл 10%', 6000, '/images/product_1317.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1318, '4/8 Сыр сливочный 1 КГ ', 44000, '/images/product_1318_1618640850.png', 1, 0, 1194, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1320, '9/11 Миф автомат 2 кг', 38000, '/images/product_1320.png', 1, 0, 3825, 0, '2 кг', 1, NULL, NULL, 0, 1, 0),
(1321, '9/12 Пемос автомат 2 кг', -38000, '/images/product_1321.png', 1, 0, 3825, 0, '2 кг', 1, NULL, NULL, 0, 1, 0),
(1322, '4/10 Сыр \"Восточный\"  1кг', 32000, '/images/product_1322_1602759244.png', 1, 0, 1194, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 4, 1, 0),
(1323, '4/11 ', -8000, '', 1, 0, 1194, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1324, '9/13 Losk Color автомат 2,7 кг', 60000, '/images/product_1324.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1326, '9/14 Зелёный чай ручной 900 г', 18000, '/images/product_1326.png', 1, 0, 3825, 0, '900 гр', 1, NULL, NULL, 5, 1, 0),
(1327, 'Tide автомат 400 гр', 13000, '/images/product_1327.png', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(1328, '9/15 Пемос ручной 320 гр', 7000, '/images/product_1328.png', 1, 0, 3825, 0, '320 гр', 1, NULL, NULL, 0, 1, 0),
(1329, 'Сыр (Украина) 1кг', 50000, '', 0, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1330, 'Қатиқ 1 л', 6000, '', 0, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(1331, '4/12 Қатиқ садаф 1 л ', 9000, '/images/product_1331_1618640885.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1333, '4/13 Қатиқ \"Био Класс\" 450гр  Садаф ', 5000, '/images/product_1333.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1334, '4/14 Брынза садаф  ', 40000, '/images/product_1334.png', 1, 0, 1194, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1336, '9/16 Хужалик совуни 250 гр', -3000, '/images/product_1336.png', 1, 0, 3825, 0, '240 гр', 1, NULL, NULL, 0, 1, 0),
(1337, '9/17 Хужалик совуни 270 гр', 3000, '/images/product_1337.png', 1, 0, 3825, 0, '270 гр', 1, NULL, NULL, 0, 1, 0),
(1340, '9/18 Совун Palmolive 90 гр', 5000, '/images/product_1340.png', 1, 0, 3825, 0, '90 гр', 1, NULL, NULL, 0, 1, 0),
(1341, '9/19 Совун Palmolive 150 гр', 8000, '/images/product_1341.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1342, '6/1 Гурунч (девзира) 1 кг', 14000, '/images/product_1342.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(1343, '6/2 Гурунч (чунғара) 1 кг			', 35000, '/images/product_1343.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1344, '6/3 Гурунч Аланга (Ош) 1кг		', 11000, '/images/product_1344.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1345, '6/4 Гурунч (суюқ-13) 1 кг			', 10000, '/images/product_1345.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1346, '6/5 Горох 1 кг ', 8000, '/images/product_1346.png', 0, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1347, '6/6 Гречка 1 кг', 16000, '/images/product_1347.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1348, '6/7 Перловка 1 кг', 9000, '/images/product_1348.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1349, '9/20 Совун Duru 4x115гр', 16000, '/images/product_1349.png', 1, 0, 3825, 0, '4 шт', 1, NULL, NULL, 0, 1, 0),
(1350, 'Жуари 1кг', 8000, '', 0, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1351, '9/21 Совун Nivea 100 г', -10000, '/images/product_1351.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1352, '6/8 Жувори 1кг', 10000, '/images/product_1352.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1353, '6/9 Ловия 1кг', 16000, '/images/product_1353.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1354, '6/10 Мош 1кг', 14000, '/images/product_1354.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1355, '6/11 Нухат (эрон)', 20000, '/images/product_1355.png', 1, 0, 1198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1356, '9/22 Пемолюкс 480 гр', 8000, '/images/product_1356.png', 1, 0, 3825, 0, '480 гр', 1, NULL, NULL, 0, 1, 0),
(1357, '9/23 Чистоль Зелёный чай ', -7000, '/images/product_1357.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1358, '18/25 Gorilla Энергетик', 9000, '/images/product_1358.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1359, '18/26 18+ Энергетик 500мл', 7500, '/images/product_1359.png', 1, 0, 2471, 0, '0,5 л', 1, NULL, NULL, 0, 1, 0),
(1360, '18/27 18+ Энергетик 250мл', 5500, '/images/product_1360.png', 1, 0, 2471, 0, '0,25 л', 1, NULL, NULL, 0, 1, 0),
(1361, '9/9 Зайтун ёги 500 мл', 75000, '/images/product_1361.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1362, '9/10 Зайтун ёги 250 мл', 35000, '/images/product_1362.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1364, '18/28 Энергетик Adrenaline 250мл  ', 7000, '/images/product_1364.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 1, 1, 0),
(1366, '18/29 Энергетик Adrenaline 500мл ', 11000, '/images/product_1366.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 5, 1, 0),
(1370, '9/24 Чистоль Comet', 11000, '/images/product_1370.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1372, '9/11 Маргарин Щедрое Лето 500 гр', 17000, '/images/product_1372.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1374, '9/25 Гель Туалетный Утёнок 500мл', 18000, '/images/product_1374.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1376, '9/26 Domestos Тозалик воситаси 1л', 26000, '/images/product_1376.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1378, '9/12 Сариёг PRESIDENT 200 гр', 30000, '/images/product_1378.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1381, '9/13- Сариёг PRESIDENT 400 гр', 50000, '/images/product_1381.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1382, '9/27 Освежитель Воздуха Airwick 240мл', -22000, '/images/product_1382.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1384, '24/1 Каша Nestle безмолочная 5 злаков 6 ой 200гр', 26000, '/images/product_1384.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1385, '516-Каша Nestle рисовая гипоаллергенная 4 ой 200гр', 26000, '/images/product_1385.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1387, '16/1 IMPRA чёрный 90 гр', 18000, '/images/product_1387.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1388, '517-Каша Nestle молочная мультизлаковая 9 ой 220гр', 26000, '/images/product_1388.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1389, 'TUDOR чёрний 100гр', 16000, '/images/product_1389.png', 0, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1391, 'Каша Nestle молоч рисовая с яблоком 4 ой 220гр', 23000, '/images/product_1391.png', 0, 0, 1225, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1394, '16/2 Чой чёрный 1 кг ', 40000, '/images/product_1394.png', 1, 0, 2350, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1396, '16/3 Ахмад пак / 25 дона кук ', 24000, '/images/product_1396.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1400, 'Каша Nestle гречн. гипоаллер б/молотый 4 ой 250гр', 26000, '/images/product_1400.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1403, '24/5 Каша Nestle молоч овсяная с грушей 6 ой 220гр', 26000, '/images/product_1403.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1404, '16/4 Nescafe classik кофе 100гр', 31000, '/images/product_1404.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 5, 1, 0),
(1405, '16/5 Nescafe classik кофе 250 гр', 75000, '/images/product_1405.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1406, '16/6 JACOBS кофе 95 гр', 42000, '/images/product_1406.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1408, '24/6 Смесь Nutrilak 1 /  0-6 ой 350гр', 34000, '/images/product_1408.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 5, 1, 0),
(1409, '16/7 Nescafe GOLD 95 гр', 29000, '/images/product_1409.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1410, '16/8 Nescafe classik кофе 50гр', 15000, '/images/product_1410.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1411, '24/7 Cмесь Nutrilak 2 /  6-12 ой 350гр', 36000, '/images/product_1411.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 5, 1, 0),
(1412, '24/8 Смесь Nutrilak 3 детское молочко 12 ой 350гр', 36000, '/images/product_1412.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1413, '16/9 Какао Nesquik 250 гр', -20500, '/images/product_1413.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1414, '16/10 Какао Nesquik 500гр', -31500, '/images/product_1414.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1415, '16/11 Фрима (курук сут)  500 гр', 30000, '/images/product_1415.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1416, '24/9 Смесь Nutrilon 1 Pronutra+  0-6 ой 400гр', 69000, '/images/product_1416.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1417, '24/10 Смесь Nutrilon 2 Pronutra+  6-12 ой 400гр', 69000, '/images/product_1417.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1418, 'Смесь Nutrilon 3 Pronutra+  12 ой 400гр', 69000, '', 0, 0, 1225, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1419, 'Смесь Nutrilon 3 Pronutra+  12 ой 400гр', 69000, '', 0, 0, 1225, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1420, '24/11 Смесь Nutrilon 3 Pronutra+   12 ой 400гр', 69000, '/images/product_1420.png', 1, 0, 3828, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1421, 'Шерин  (капчоный) Московская 1 п/к', 27000, '/images/product_1421.png', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1422, 'Шерин  (капчоный) п/к  сервелат 1 дона', 30000, '/images/product_1422.png', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1423, '24/12 Подгузники Pampers new baby-dry 1 / 27 шт', -40000, '/images/product_1423.png', 1, 0, 3828, 0, '1 блок', 1, NULL, NULL, 0, 1, 0),
(1424, '24/13 Подгузники Pampers active baby-dry 3 / 22 шт', 44000, '/images/product_1424.png', 1, 0, 3828, 0, '1 блок', 1, NULL, NULL, 0, 1, 0),
(1425, 'Рузметов (капчоный) п/к   1 дона', 42000, '/images/product_1425.png', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1426, '2/5 \"Рузметов\" \"Алпинскый\" копчёная колбаса 1палка', -53000, '/images/product_1426.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1427, '24/14 Подгузники Pampers Prima 4 /50 дона', 95000, '/images/product_1427.png', 1, 0, 3828, 0, '1 блок', 1, NULL, NULL, 5, 1, 0),
(1428, '24/15 Подгузники Prima 2 / 72 дона', 95000, '/images/product_1428.png', 1, 0, 3828, 0, '1 блок', 1, NULL, NULL, 0, 1, 0),
(1431, '5/1- Макарон Makfa 400 гр', 8000, '/images/product_1431.png', 1, 0, 1197, 0, '1 пач', 1, NULL, NULL, 0, 1, 0),
(1432, '5/2 Макарон Makfa спагетти 400 гр', 9500, '/images/product_1432.png', 1, 0, 1197, 0, '1 пач', 1, NULL, NULL, 0, 1, 0),
(1435, '5/3- Ун \"Дани\" высший - 1 кг', 7000, '/images/product_1435.png', 0, 0, 1197, 0, '1 кг', 1, NULL, NULL, 0, 1, 0),
(1436, '5/4 ун дани 1 сорт', 6000, '/images/product_1436.png', 1, 0, 1197, 0, '1 кг', 1, NULL, NULL, 5, 1, 0),
(1437, '15/1 Шоколад мини Snickers 1 кг', 80000, '/images/product_1437.png', 1, 0, 2198, 0, '1 кг', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1438, '15/2 Шоколад мини Twix 1 кг', 80000, '/images/product_1438.png', 1, 0, 2198, 0, '1 кг', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1439, '15/3 Шоколад мини Nuts 1 кг', -72000, '/images/product_1439.png', 1, 0, 2198, 0, '1 кг', 1, NULL, NULL, 0, 1, 0),
(1440, '15/4 Шоколад мини Mars 1 кг ', 80000, '/images/product_1440.png', 1, 0, 2198, 0, '1 кг', 1, NULL, NULL, 5, 1, 0),
(1441, '15/5 Шоколад мини Bounty 1 кг', 80000, '/images/product_1441.png', 1, 0, 2198, 0, '1 кг', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1442, '15/6 Шоколад мини Kit Kat 1 кг', 80000, '/images/product_1442.png', 1, 0, 2198, 0, '1 кг', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1443, '15/7 Шоколад Nestle молочный 90 г', 9000, '/images/product_1443.png', 1, 0, 2198, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(1444, '15/8 Шоколад Россия 90 гр', 9000, '/images/product_1444.png', 1, 0, 2198, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(1445, '15/9 Шоколад Alpen Gold 90 гр', 10000, '/images/product_1445.png', 1, 0, 2198, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(1446, '12/1 Бисквит Барни 150 гр 5 шт', 14000, '/images/product_1446.png', 1, 0, 1502, 0, '150 гр', 1, NULL, NULL, 0, 1, 0),
(1447, '15/10 Шоколадная паста Сhococream 400 гр', 20000, '/images/product_1447.png', 1, 0, 2198, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(1448, '15/11 Шоколадная паста Nutlet 350 гр', 45000, '/images/product_1448_1609141683.png', 1, 0, 2198, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(1449, '15/12 Шоколадная паста Chocotella 330 гр', 20000, '/images/product_1449.png', 1, 0, 2198, 0, ',', 1, NULL, NULL, 0, 1, 0),
(1450, '15/13 Шоколад Medunok 1 кг', 46000, '/images/product_1450.png', 1, 0, 2198, 0, '1 кг', 1, NULL, NULL, 0, 1, 0),
(1451, '18/30 Hydrolife 5 л негазированная', 6000, '/images/product_1451.png', 1, 0, 2471, 0, '1 дона', 1, NULL, NULL, 5, 1, 0),
(1453, '9/28 Persil Автомат 1.5 кг', 32000, '/images/product_1453.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1454, '9/29 Ariel автомат 1,5 кг', 38000, '/images/product_1454.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1455, '9/30 Миф автомат 4 кг', 77000, '/images/product_1455.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1456, '9/31 Пемос автомат 3,5 кг', 54000, '/images/product_1456.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1457, '9/32 Пемос автомат 5,5 кг', 85000, '/images/product_1457.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1458, '9/33 Берёзовая роща автомат 1,8 кг', 36000, '/images/product_1458.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1459, '9/34 Лоск автомат 1,5 кг', 30000, '/images/product_1459.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1460, '9/35 Краска \"Рябина\" 014 Русый', 15000, '/images/product_1460_1602760579.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1461, '9/36 Зелёный чай автомат 1,5 кг', 34000, '/images/product_1461.png', 1, 0, 3825, 0, '1 пачка', 1, NULL, NULL, 0, 1, 0),
(1462, '9/37 Fairy гел 450 гр', 14000, '/images/product_1462.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1463, '9/38 Капля гель 500 гр', 8000, '/images/product_1463.png', 1, 0, 3825, 0, '1 дона', 1, NULL, NULL, 0, 1, 0),
(1466, '11/9 Бодом 1 кг', 85000, '/images/product_1466.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1467, '11/10 Писта мумтоз 1 кг', 120000, '/images/product_1467.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1468, '11/11 Писта Ахмадь 1 кг', 130000, '/images/product_1468.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1469, '11/12- Майиз 1кг', 45000, '/images/product_1469.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1470, '11/13 Ер Ёнгок 1 кг', 21000, '/images/product_1470.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1472, '11/14 Куритилган урик 1 кг', 35000, '/images/product_1472.png', 0, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1473, '11/14 Ёнгок магиз  150 г', -10000, '/images/product_1473.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1474, '11/15 Ковурилган нухат 250 г', 25000, '/images/product_1474.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 2, 1, 0),
(1475, '11/16 Миндаль урик 1 кг', 25000, '/images/product_1475.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1476, '11/17 Миндаль бодом 1кг', 80000, '/images/product_1476.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1477, '11/18 Миндаль кунжут 1 кг', 25000, '/images/product_1477.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(1480, '9/14 Янтар 1л', 25000, '/images/product_1480.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1481, '9/15 Cарёг NESTLE 400 гр', 37000, '/images/product_1481.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1482, '9/16 Ярко 1 л', 24000, '/images/product_1482.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1483, '9/17 Маргарин Щедрое Лето 1000 гр', 32000, '/images/product_1483.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1484, '18/31 Sprite 1 л', 9500, '/images/product_1484.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1485, '4/15 Қатиқ Даза 5%', -5500, '/images/product_1485.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1486, 'Лаваш хамир 1 пачка', 5000, '/images/product_1486.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1487, '16/13 Шакар хоразм 1 кг', 9500, '/images/product_1487.png', 1, 0, 2350, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 2, 1, 0),
(1488, '1/18 Памидор ', 5000, '/images/product_1488.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1489, '20/01 Хлеб (буханка) 1 дона', 1500, '/images/product_1489.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 3.6666666666666665, 1, 0),
(1490, '20/02 Хлеб ржаной 1 дона', -4500, '/images/product_1490.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(1491, '20/03 Батон ржаной 1 дона', 5000, '/images/product_1491.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(1492, '20/04 Патир ёгли (кичкина) - 1 дона', 7500, '/images/product_1492.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(1493, '20/05 Патир ёгли (катта) - 1 дона', 9500, '/images/product_1493.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(1495, '9/39 Совун Duru Fresh 4 дона ', 21000, '/images/product_1495.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1496, '5/5- Паста Makiz 400гр ', 8000, '/images/product_1496.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1497, '5/6 Макарон  Makiz 700 гр', 9500, '/images/product_1497.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1499, '5/7 \"Rollton \"60 гр', 2000, '/images/product_1499.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1500, '5/8 \"EYVA\" макарон 300 гр', 5000, '/images/product_1500.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1502, '12/Печенилар ', 0, '/images/product_1502_1617342409.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1503, '21/76 Шампунь Syoss 1 дона', 29000, '/images/product_1503.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1504, '21/75 Шампунь Nivea 1 дона', 28000, '/images/product_1504.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1505, '21/74 Шампунь Head&Shoulders 200 мл', 22000, '/images/product_1505.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 5, 1, 0),
(1506, '21/73 Шампунь Head&Shoulders 400 мл', 34000, '/images/product_1506.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1507, '21/72 Шампунь Clear 200 мл', 18000, '/images/product_1507.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1508, '21/71 Шампунь Clear 400 мл', 30000, '/images/product_1508.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1509, '21/1 Шампунь Elseve 400 мл', 30000, '/images/product_1509.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 4, 1, 0),
(1510, '21/2 Шампунь Palmolive 380 мл', 24000, '/images/product_1510.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1511, '21/3 Влажные салфетки 120 дона', 12500, '/images/product_1511.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1512, '21/4 Влажные салфетки 72 дона', 7500, '/images/product_1512.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1513, '21/5 Туалетная Бумага Lotus 1 пачка', 16000, '/images/product_1513.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1514, '21/6 Туалетная Бумага Jasmin 1 пачка', 12000, '/images/product_1514.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1515, 'Зубная паста Colgate ', 5000, '/images/product_1515.png', 0, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1516, '21/7 Зубная паста Лесной бальзам ', 9000, '/images/product_1516.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1517, '21/8 Шампунь Pantene 400 гр', 31000, '/images/product_1517.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 5, 1, 0),
(1518, '5/9- Финчуза 1 пачка', 4000, '/images/product_1518.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1520, '4/16 Қатиқ ченптон Даза 10%', -6000, '/images/product_1520_1618641159.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1521, '4/17 Молоко сгущенное \"Ичня\" 480 гр', 11000, '/images/product_1521.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1522, '1/19- Ошковок (салла) 1 кг', -2500, '/images/product_1522.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1523, '20/06 Оби нон 1 дона', 3000, '/images/product_1523.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 5, 1, 0),
(1524, '20/07 Лаваш хамири 1 пачка', 5000, '/images/product_1524.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 3.4, 1, 0),
(1525, '8/1 Кетчуп \"Mонарх\" 300 гр', 4000, '/images/product_1525.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1526, '8/2 Кетчуп \"Mонарх\" 850 гр', 8000, '/images/product_1526.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1527, 'Маёнез монарх  500 мл', 5500, '/images/product_1527.png', 0, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(1528, '8/3 Майонез \"Монарх\" 300 мл', 4000, '/images/product_1528.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1529, '8/4 Майонез \"Монарх\" 850гр', 8500, '/images/product_1529.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1530, '8/5 Майонез \"Оливьез классическое\" 200 мл', 6000, '/images/product_1530_1603937912.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1531, '11/19 Узум 1кг', -30000, '/images/product_1531.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1533, '1/20- Сабзи сарик  1 кг', 9000, '/images/product_1533.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 3, 1, 0),
(1535, '12/2 Печенье Юбилейное 112 гр', 9000, '/images/product_1535.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1536, '12/3 Печенье Юбилейное молочное с глазурью', -9000, '/images/product_1536.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1538, '9/18 Украинское сарёг 200 гр', 10000, '/images/product_1538.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1540, '4/24 Тухум 1 дона', 1000, '/images/product_1540.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1541, '16/14 Кук чой N-110 \"Сарбон\" 1кг', 28000, '/images/product_1541.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1542, '16/15 Кук чой No 95 1кг', 35000, '/images/product_1542.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1543, '16/16 IMPRA кора мевали 25+5 шт', -17000, '/images/product_1543.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1545, '13/Эрмакка', 0, '/images/product_1545.jpg', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1546, 'Чипсы CHEERS 30 гр', 3000, '/images/product_1546.png', 0, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1547, '13/1- Чипсы \"CHEERS\" 30 гр', 3000, '/images/product_1547.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(1548, '13/2 Чипсы \"CHEERS\" 70 гр', 5500, '/images/product_1548.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(1549, '13/3 Чипсы \"Lays\" 225 гр', 19000, '/images/product_1549.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(1550, '13/4 Чипсы \"Lays\" 90 гр', 8000, '/images/product_1550.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(1551, '13/5 Чипсы \"Lays\" 150 гр', 13000, '/images/product_1551.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 4, 1, 0),
(1552, '13/6 Bio курут \"Ermak\" 30 гр', 4000, '/images/product_1552.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1553, '13/7 Bio курут \"Ermak\" 47 гр', 5000, '/images/product_1553.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1554, '9/19. Маргарин Щедрое Лето 200 гр', 7000, '/images/product_1554.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1555, '18/32 Tropic MANGO 500ml', 5000, '/images/product_1555.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1556, 'Сыр царский сливочный 1 кг', 40000, '/images/product_1556.png', 0, 0, 1193, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1557, '24/16 Подгузники Pampers Prima 3 / 62 дона', 95000, '/images/product_1557.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1558, '24/17 Pampers Prima 5 / 40 дона', 105000, '/images/product_1558.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1559, '24/18  Pampers Prima 2 / 1 дона', 1600, '/images/product_1559.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 5, 1, 0),
(1560, '24/19 Подгузники Prima Pampers 3 / 1 дона', 1600, '/images/product_1560.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1561, '24/20 Подгузники Pampers Prima 4 / 1 дона', 2000, '/images/product_1561.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1562, '24/21 Подгузники Pampers Prima 5 / 1 дона', 2500, '/images/product_1562.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1563, '4/25 Сыр восточний', 10000, '/images/product_1563_1604139664.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1564, '4/26 Сыр\" Ханский\" 300 гр', -12000, '/images/product_1564.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1565, '4/27 Сыр \"Царский\" 1 кг', -41000, '/images/product_1565.png', 1, 0, 1194, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1566, '4/28 Сыр \"Царский\" 300 гр', -12500, '/images/product_1566.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1567, '2/6 \"Шерин\" сосиски сырные 1 пачка', 23000, '/images/product_1567.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1570, 'Разрыхлитель 1 шт', 2000, '/images/product_1570.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1571, '7/1- Разрыхлитель 1 шт', 1600, '/images/product_1571.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1572, '7/2 Ванилин 1 шт', 2000, '/images/product_1572.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1573, 'Багет  1 шт', 3500, '/images/product_1573_1602840800.png', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1574, '20/08 Багет нон 1 дона', 5000, '/images/product_1574.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(1577, '21/9 Салфетки Jasmin 1 блок (16 дона)', 16000, '/images/product_1577.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 5, 1, 0),
(1578, '21/10 Салфети жасмин 1 дона', 1000, '/images/product_1578.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1581, '9/20 ёги 1 кг', 19000, '/images/product_1581.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1582, '17/1 Асал Зомин  900 гр', 90000, '/images/product_1582.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(1583, '4/29 Сыр плавленный \"VIOLA\" 200 гр', 26000, '/images/product_1583.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1584, '5/10- Лагман  (Муса) 300 гр 1 пачка', 5500, '/images/product_1584.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1586, '9/21- Пахта ёги 4,2 л', 75000, '/images/product_1586.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1587, '9/22 Сарёг Донна 82 % 0.5 кг', 20000, '/images/product_1587.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1589, '9/23 Сарёг Киевское 82,5% 500гр', 20000, '/images/product_1589.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1591, '9/24. Сарёг PRESIDENT 1 кг', 121000, '/images/product_1591.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1593, '9/40 Освежитель Воздуха Airwick 414 мл', -32000, '/images/product_1593.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1594, '9/41 Саlgon порошок 550 гр', 42000, '/images/product_1594.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1595, '9/42 Calgon таблеткали 15 дона', 45000, '/images/product_1595.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1596, '12/4 Халва подсолнечная 500 гр', -9000, '/images/product_1596.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1597, '12/5 Халва алматинская 325гр', -14000, '/images/product_1597.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1600, '9/25 Сарёг PRESIDENT 125 гр', 20000, '/images/product_1600.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1601, '9/26- Сарёг Anchor 200 гр', -27000, '/images/product_1601.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1602, '9/27- Сарёг BRAVO 450 гр', 30000, '/images/product_1602.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1603, '24/22 Подгузники Лалаку 3 / 54 дона', 80000, '/images/product_1603.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 5, 1, 0),
(1604, '24/23 Подгузники Лалаку 4 / 46 дона', 80000, '/images/product_1604.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1605, '24/24 Подгузники Лалаку 5 / 40 дона', 90000, '/images/product_1605.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1606, '24/25 Подгузники Лалаку 3 / 1 дона', 1900, '/images/product_1606.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 3, 1, 0),
(1607, '24/26 Подгузники Лалаку 4 / 1 дона', 2200, '/images/product_1607.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1608, '24/27 Подгузники Лалаку 5 / 1 дона', 2500, '/images/product_1608.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1610, '10/1 Bonduelle зеленый горошек 400г', 14000, '/images/product_1610.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1611, '10/2 Bonduelle кукуруза 400г', 14000, '/images/product_1611.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1612, '10/3 Bonduelle зеленый горошек 140г', 8000, '/images/product_1612_1618648632.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 5, 1, 0),
(1613, '10/4 Bonduelle кукуруза 140г', 8000, '/images/product_1613_1618648654.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1614, '10/5Bonduelle Фасоль белая в томатном соусе', 14000, '/images/product_1614_1618649076.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1615, '10/6 Bonduelle Фасоль красная 400г', 14000, '/images/product_1615_1618649110.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1616, '10/7 Bonduelle Фасоль белая 400г', 13000, '/images/product_1616_1618649167.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1617, '10/8 Bonduelle оливки мансанилья с лимоном 300г', 22000, '/images/product_1617_1618649214.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1618, '10/9 \"Любимый\" томатная паста 1 л', 22000, '/images/product_1618.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1619, '10/10 \"Любимый\" томатная паста 0,5 л', 11000, '/images/product_1619.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1620, '15/14 Шоколад Roshen 85 г', 10000, '/images/product_1620.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1621, '15/15 Шоколад Alpen Gold Max Fun 160 г', 18000, '/images/product_1621.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 5, 1, 0),
(1622, '15/16 Шоколад Nesquik 100 г', 10000, '/images/product_1622.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1623, '10/11 Bonduelle оливки маслины без косточки 300г', 22000, '/images/product_1623_1618649280.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1624, '10/12- Сардинелла в масле 240 г', 15000, '/images/product_1624.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1625, '10/13 Bonduelle оливки маслины без косточки 300г', 23500, '/images/product_1625_1618649571.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1626, '728-Килька \"Рижское Золото\" в томатном соусе 240 г', 10000, '/images/product_1626.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1627, '4/30 Сыр плавленный \"VIOLA\" 400 г', 46000, '/images/product_1627.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1628, '4/31 Сыр плавленный \"VIOLA\" 130 г', 15000, '/images/product_1628.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1629, '4/32 Тухум 1 клетка (30 дона)', 30000, '/images/product_1629.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1630, '5/11- Макарон Мазза 5 кг ', 40000, '/images/product_1630.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1632, '7/3 Зира 100 г', 6000, '/images/product_1632.png', 1, 0, 1199, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1633, '1/21- Салат барги 1 бог ', 2000, '/images/product_1633.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1638, '9/43 Миф автомат 400 гр', 9000, '/images/product_1638.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1639, '12/6 Подушки сладкие\"  1 кг', 26000, '/images/product_1639.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1640, 'Печенье SFAD \" Подушки сладкие\" шоколанд   1кг', 19000, '/images/product_1640.png', 0, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1641, '12/7 Подушки сладкие\"  0,5 кг', 13000, '/images/product_1641.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1642, 'Печенье SFAD \"BAYRAM CHOCO\" 0,5 кг', 8500, '/images/product_1642.png', 0, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1643, '12/8 Вафелька мини   ', 22000, '/images/product_1643.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1644, '12/9 \" Подушки сладкие\" 1 кг', -23000, '/images/product_1644.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1645, '12/10 Печенье  \" LOCHIRA \" shakarli 1 кг', -17000, '/images/product_1645.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1646, '12/11 Печенье  \" LOCHIRA \" shakarli 0.5  кг', -9000, '/images/product_1646.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1647, '5/33 \"Наш Сад\" сок  ', 8000, '/images/product_1647.png', 0, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1651, '18/34 Черноголовка 1,5 л', 7000, '/images/product_1651.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1652, '18/35 Черноголовка тархун 1,5 л', 7000, '/images/product_1652.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0);
INSERT INTO `products` (`id`, `name`, `price`, `image`, `partner_id`, `group`, `parent_id`, `type`, `comments`, `active`, `date_created`, `options`, `rating`, `status`, `discount`) VALUES
(1656, '11/20 Анор 1кг', -17000, '/images/product_1656.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1657, '12/12 Печенье (курук ) 1кг', 15000, '/images/product_1657.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1658, '12/13 Печенье (курук) 0,5 кг', 7000, '/images/product_1658.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1659, '18/36 Сок \"J+\"', 9000, '/images/product_1659.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1660, '9/28 Украинское 500 гр', 23000, '/images/product_1660.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1661, '9/29- Сарёг Деревенское  200 гр', 8500, '/images/product_1661.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1662, 'Шерин \"Московский\" 1 п/к ', 27000, '', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1663, '2/7 \"Шерин\" копчёная колбаса  \"Сервелат\" 1 палка', 40000, '/images/product_1663.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 4.666666666666667, 1, 0),
(1664, 'Шерин (Капчёный ) сервелат  ', 33000, '', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1665, '2/8 \"Рузметов\" копчёная колбаса 1 палка', -41000, '/images/product_1665.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1667, '9/30 Сарёг NESTLE 200 гр', 22000, '/images/product_1667.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1669, '9/44 Порошок \"Ушастый Нянь\"  400гр', 11500, '/images/product_1669.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 3, 1, 0),
(1670, '9/45 \"Чистин Антижир \" ошхона учун', 18000, '/images/product_1670.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1671, '9/46 \"Yumos\"  освежитель', 32000, '/images/product_1671.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1672, '18/37 \"Мохито\" ', 10000, '/images/product_1672.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 5, 1, 0),
(1673, '2/9\"Шерин\" копчёная колбаса Салями 1 палка ', 43000, '/images/product_1673.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1674, '2/10 \"Шерин\" Саnada сосиски', 18000, '/images/product_1674.png', 1, 0, 1192, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1675, '2/11 \"Шерин\" молочные сосиски 1 пачка		', 23000, '/images/product_1675.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1676, '4/33 Молоко сгущенное \"Ичня\" 370 гр', 9000, '/images/product_1676.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1680, 'Neskafe 3 в 1 слассик', 1200, '/images/product_1680.png', 0, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1681, '16/18 Neskafe 3 /1 classik ', 2000, '/images/product_1681.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1682, '16/19 JACOBS 3/1 \"LATTE\"', -1800, '/images/product_1682.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1683, '16/20 JACOBS 3/1 \"ОRGINAL\"', -1800, '/images/product_1683.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1684, '16/21 JACOBS \"MONARCH\"', -1800, '/images/product_1684.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1685, 'Семечки \"Джинн\" 140гр', 9000, '', 0, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1687, '13/8 Семечки \"Джинн\" 35 гр', -2500, '/images/product_1687.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1688, '13/9 Семечки \"Джинн\" 140 гр', 8500, '/images/product_1688.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1689, '2/12 \"Шерин\" копчёная колбаса Московкая  1-пк', 45000, '/images/product_1689.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1690, '2/13 Колбаса \"Андалус\" \" Докторская\" ', 49000, '/images/product_1690.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(1691, '9/31 Vita Milk \"Сливочное особое\" сарёг 200 гр', 13000, '/images/product_1691.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1692, '9/32 VitaMilk\"Крестьянское классическое\"сарёг500гр', -28000, '/images/product_1692.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1693, '9/33 \"Домашнее застолье\" маргарин 200 гр', 5500, '/images/product_1693.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1694, '9/34\"Домашнее застолье\" маргарин 500 гр', 14000, '/images/product_1694.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1695, '9/35 Сарёг Деревенское 500 гр', 20000, '/images/product_1695.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1697, 'Туз эктсра ', 2500, '', 0, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1698, '7/4 Туз экстра ', 4000, '/images/product_1698.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1700, '13/10 Семeчки \"ERMAK\" 160 гр', 8500, '/images/product_1700.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1701, '18/38 \"Nesquik\" коктейл шоколадный  200 мл', 3500, '/images/product_1701.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1702, 'Дезодорант-  NIVEA МЕN  Свежесть 150мл', 19500, '', 0, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1703, '673- Дезодорант - женский  \"NIVEA\" Черное и Белое ', 20000, '/images/product_1703.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1704, '21/12 Дезодорант - Rexona МЕN  200мл', 23000, '/images/product_1704.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1705, 'Дезодорант- женский  \"Rexona\" biorythm ', 19000, '/images/product_1705.png', 0, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1706, '21/13 Дезодорант- женский \"DEONICA\" 200 мл', 17000, '/images/product_1706.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1707, '21/14 Дезодорант- \"DEONICA\" FOR МЕN 200мл', 17000, '/images/product_1707.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1708, '21/15 Дезодорант - NIVEA МЕN 150мл', 22000, '/images/product_1708.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1709, '21/16 Дезодорант- женский  \"Rexona\"', 20000, '/images/product_1709.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1710, '21/17 \"NIVEA\" Пена для бритья ', 30000, '/images/product_1710.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1711, '21/18 \"Arko\" Пена для бритья ', 25000, '/images/product_1711.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1712, '21/19 \"Gillette\" Пена для бритья ', 28000, '/images/product_1712.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1713, '21/20 Зубная щетка \" Colgate\"', 5500, '/images/product_1713.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1715, 'Манная крупа \"Пассим\" 700 гр', 8500, '', 0, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1717, '6/12 Манная крупа \"Макфа\"700гр', 17000, '/images/product_1717.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1718, '18/39 Холодный чай \"Fuse tea\"  450 мл', 4000, '/images/product_1718.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1719, '18/40 \"Аloe Health\"  UZ 500 мл', 8500, '/images/product_1719.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(1720, '2/14 Таллинская копчёная колбаса   1-пк', 17000, '/images/product_1720.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1723, '10/15- Консерваланган Бодринг 1л-банка   ', 11000, '/images/product_1723.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1724, '10/16 Консерва Бодринг (майдаси) 1л', 11000, '/images/product_1724.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1725, '8/6 Майонез \"Оливье классический\" 450мл', 10000, '/images/product_1725_1602759200.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1726, 'Шерин для завтрик (варёный)', 39000, '', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1727, '2/17 \"Sherin\"  \"Для завтрака\" варёная колбаса 1 кг', 45000, '/images/product_1727.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1728, '12/14 Печенье  \"BAYRAM CHOCO\" 0,5 кг', -10000, '/images/product_1728.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1731, '9/47 Gel \"Venus\" 1000гр', 16000, '/images/product_1731.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1732, '9/48 Gel \"Venus\" 450 гр', 8000, '/images/product_1732.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1736, '21/21 Зубная щетка \" Dental pro\"', -2500, '/images/product_1736.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1737, '21/22 Зубная щетка \"DEMEX\"', 2500, '/images/product_1737.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1740, '21/23 \"Сolgate Мах Fresh\"125 гр', 16000, '/images/product_1740.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1743, '5/12- \"BIG BON\" 75г', 3000, '/images/product_1743.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1744, '5/13- \"Доширак \" 90 гр', 6000, '/images/product_1744.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1745, '21/24 \"Gillette 5+1\" бритва ', 25000, '/images/product_1745.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1746, '21/25 Шампунь \"Nivea Мен\" 250 мл Сила угля', 28000, '/images/product_1746.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1757, '12/15 Печенье \" EURO\" 1 кг', -15000, '/images/product_1757_1602759802.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1758, '12/16 Печенье \" EURO\" 0,5 кг', -8000, '/images/product_1758_1602759834.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1759, '15/16 Шоколад \"Марс\" 50гр -1 шт ', 6000, '/images/product_1759.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1760, '15/17 Шоколад \"Сникерс\" 50гр -1 шт ', 5000, '/images/product_1760.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1761, '15/18 Шоколад \"Кit Каt \" 40гр -1 шт ', 6000, '/images/product_1761.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1762, '15/19 Шоколад \"BOUNTY\" 27.5 гр -1 шт ', 5000, '/images/product_1762.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1763, '15/20 Шоколад \"Twix\"   1 шт ', 5000, '/images/product_1763.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1768, '14/Печёные', 0, '/images/product_1768_1609653392.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(1776, '16/22 Чой кора \"Alokazay\" пакетчали 25 та', 15000, '/images/product_1776.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1779, '16/23 Чой кора  \"Alokazay\" пакетчали 100 дона', 40000, '/images/product_1779_1602759978.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1780, '16/24 Массofe 3/1', 2000, '/images/product_1780.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1782, '5/14- Макарон 1кг', 8000, '/images/product_1782.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1783, '12/17 Сhoco Pie 12 - дона', 26000, '/images/product_1783.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1784, '12/18 Сhoko-Pie  6-дона', 14000, '/images/product_1784.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1785, '13/11- Оrbit', 4500, '/images/product_1785.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(1786, '9/49 Миф ручной 400 гр', 8000, '/images/product_1786.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1787, '9/50 Rакsha  чистол', 9000, '/images/product_1787.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1788, '1/22- Маккажухори (хом) 1-дона', 3000, '/images/product_1788.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1789, '11/21 Беҳи 1кг', 35000, '/images/product_1789.png', 1, 0, 1228, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1790, '281 Зубная щётка (для детей)', 2500, '/images/product_1790.png', 0, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1792, '21/26 Влажные салфетки 25 дона', 5000, '/images/product_1792.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 4, 1, 0),
(1793, '21/27 Совун \"Саmargue Sea Salt\" 200 гр', 12500, '/images/product_1793.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1794, '21/28 Совун \"SILK\"', 5000, '/images/product_1794.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1796, '21/29 Ватные палочки 100 шт', 5000, '/images/product_1796.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1797, '21/30 Ватные палочки 200 шт ', 7000, '/images/product_1797.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1798, 'Варёное молоко  сгущенное 700 гр ', 10500, '', 0, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(1799, '4/35 Сгущенное молоко (Варёное)800 гр', 12000, '/images/product_1799.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 3.5, 1, 0),
(1800, '4/36 Сгущенное молоко (Варёное)500 гр', 10000, '/images/product_1800_1602841491.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1803, '4/37 Сгущенное молоко (Варёное) 370 гр', 7000, '/images/product_1803.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1805, '9/51 Тозалик матоси (чанг учун) 5 шт ', -17000, '/images/product_1805.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1807, '9/52 Фло жидкий гель (кир ювиш учун)', 35000, '/images/product_1807.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1808, '9/53 \"York\" катта губка  5 шт ', -5500, '/images/product_1808.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1809, '9/54 \"York\" кичик губка  10 шт', -7500, '/images/product_1809.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1810, 'Мочалка  ', 14500, '/images/product_1810.png', 0, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1811, '4/38 Йогурт  \"Нежный\" 1 шт ', 3500, '/images/product_1811.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(1812, '24/28 Подгузники Лалаку 2/ 82 дона', 85000, '/images/product_1812.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1814, '24/29 Подгузники Лалаку 2/ 1 дона', 1300, '/images/product_1814.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1815, '24/30 Подгузники Prima aktif bebek 4/24 дона', 60000, '/images/product_1815_1602860293.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(1817, '1/24- Ок пиёз (салатный) 1кг', 7500, '/images/product_1817_1610767670.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1818, '1/25- Турп 1кг', -3000, '/images/product_1818_1610768005.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1819, '1/26- Пиёз ', 2500, '', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1820, 'Совун \"Johnsons\" 125 гр', 6000, '', 0, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1822, '1/27- Ошковок 1 кг', -15000, '/images/product_1822_1610767460.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1823, '8/9 Майонез \"Оливье  классическое\" 450 мл', -10000, '', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1825, '9/36 Янтар 0,5 л', -11000, '/images/product_1825.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1826, '9/37 яркое 0,5 л', -11000, '', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1830, '16/26 Новвот', 13000, '/images/product_1830.png', 1, 0, 2350, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1831, '9/38- Маргарин Татли 250гр', 6500, '/images/product_1831.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1832, '13/12 Семeчки \"ERMAK\" 160 гр', 9000, '/images/product_1832.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1833, '13/13 Семeчки \"ERMAK\" 100 ГР', 5500, '/images/product_1833.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1834, '13/14 \"ERMAK\" АРАХИС 50 ГР', 4500, '/images/product_1834.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1835, '13/15 \"ERMAK\" МИНДАЛЬ 40 ГР', 6500, '/images/product_1835.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1836, '13/16 \"ERMAK\" ФИСТАШКИ 30 ГР', 10000, '/images/product_1836.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(1839, '7/5 Туз Орзу  1кг ', 3000, '/images/product_1839.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1840, '12/19 Бисквит Рулет \"Яшкино\"', 7000, '/images/product_1840.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1841, '9/55 Ойна латта \"Дельфин\" ', 8000, '/images/product_1841.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1842, '9/56 Порошок  \"Доня\"  Ручной 250 гр', -3000, '/images/product_1842.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1843, '9/57 Порошок \"Апрел\" Ручной 250 гр', 2500, '/images/product_1843.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1845, '16/28 КАКАО 100 ГР', 5000, '/images/product_1845.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1846, '7/6 \"Сода\" Пищевая  500 гр', 4500, '/images/product_1846.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1847, '7/7 Дрожжи \"Ангел\" 500 гр ', -20000, '/images/product_1847.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1848, '7/8 \"Gallina Blanca\" Говяжий бульон', 4000, '/images/product_1848_1615111603.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1849, '10/17\"Naturella\"  Зелёньй  горошек ', 8000, '/images/product_1849.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1850, '10/18 \"Naturella\" Кукуруза', 8000, '/images/product_1850.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1852, '1/28- Шолгом Бешарик 1кг', -4000, '/images/product_1852.png', 1, 0, 1191, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1853, '5/15 Лапша Классическая  (Роллтон) 400 гр', 8000, '/images/product_1853.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1854, '18/41 Энергетик  Zip 0.25 мл', 5000, '/images/product_1854.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 5, 1, 0),
(1857, '7/9 Зира 50 гр ', 3000, '/images/product_1857.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1860, '7/10 Кашнич Туйилган 50 гр', 2000, '/images/product_1860.png', 0, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1861, '7/10 Кашнич Дона 50 гр', 2000, '/images/product_1861.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1862, '7/11 Туйилган  Аччик  Калампир 50 гр', 2000, '/images/product_1862.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1863, '7/12 Туйилган Кизил Болгар 50 гр', 2000, '/images/product_1863.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1864, '7/13 Туйилган Мурч 50 гр ', 6000, '/images/product_1864.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1865, '7/14- Седона Кора 50 гр ', 3500, '/images/product_1865.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1866, '7/15 Ок Кунжут 50 гр', 2000, '/images/product_1866.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1867, '8/10 Майонез \"Оливье  классическое\"  850 мл', 19000, '/images/product_1867.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1868, '1/29- Редка 1 бог', -2000, '/images/product_1868.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1869, '9/40 Vita Milk \"Сливочное особое\" сарёг  500 гр ', 21500, '/images/product_1869.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1870, '9/41-Vita Milk \"Шоколадное 500 гр', 21500, '/images/product_1870.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1871, '9/42 \"Домашнее застолье\"  маргарин 1 кг', 26000, '/images/product_1871.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1872, '9/43- Маргарин Татли 500 гр ', 13000, '/images/product_1872.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1882, '16/29\"Jardin\" 95гр', -35500, '', 1, 0, 2350, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(1883, '9/44 Маргарин (Маселко) 200 гр 72%', 5000, '/images/product_1883.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1884, '9/45 Маргарин (Маселко) Десертньй 200 гр 40%', 3500, '/images/product_1884.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1887, '10/19-Bonduelle оливки с голубым сыром 300г', 22000, '/images/product_1887_1618649338.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(1890, '16/30 Чой  \"Тесс\" кора  25 дона', 18000, '/images/product_1890.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1891, '7/16 Туз  Роял  1 кг', 2000, '/images/product_1891.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1895, '781- Стрейч  ', 5000, '/images/product_1895.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1896, '782- Gurgut  1 пачка', 2500, '/images/product_1896.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1898, '7/17- Мурч Туйилган 50 гр ', 4000, '/images/product_1898.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1899, '7/18 Маккаи сано ', 2500, '/images/product_1899.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 5, 1, 0),
(1904, '5/16 Макарон Makfa соломка 400 гр', 9000, '/images/product_1904.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1905, '5/17 Спагетти (Роллтон) 400 гр', 7500, '/images/product_1905.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1906, '7/19 Занжабил (имбир) 50 гр', 4000, '/images/product_1906.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1907, '1/30- Бакилажон ', 3000, '/images/product_1907.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(1911, '5/18 Чучвара (Муса) 300 гр', 12000, '/images/product_1911.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1912, '5/19 Чучвара (Муса) 500 гр', 18000, '/images/product_1912.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1913, '5/20 Чучвара (Муса) 200 гр', 8000, '/images/product_1913.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 5, 1, 0),
(1915, '15/21 Шоколад (Картошка) 1 кг', 38000, '/images/product_1915.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 5, 1, 0),
(1916, '15/22 Шоколад (крокант) 1 кг', 38000, '/images/product_1916.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1917, '5/21- Ун \"Адмирал\" 25 кг 1-сорт', 120000, '/images/product_1917_1618642010.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1919, '5/22- Ун \"Честер\" 25 кг 1-сорт', 120000, '/images/product_1919_1618642034.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(1920, '5/23- Ун \"Ярко\" 25 кг 1-сорт', 120000, '/images/product_1920_1618642049.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 3, 1, 0),
(1924, '12/20 Топленое молоко 1 кг', 17000, '/images/product_1924.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1925, '12/21  Топленое молоко 0,5 гр', 8500, '/images/product_1925.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1928, '12/22 Печенье  \"LOCHIRA\" ЧОКО 1 кг', -19000, '/images/product_1928.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1929, '12/23 Печенье SFAD \"LOCHIRA\" ЧОКО 0,5 гр', -9500, '/images/product_1929.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(1945, '9/46- Доня ёг 5 л (пахта)', 100000, '/images/product_1945.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1954, '9/47 Ёг Доня 3 л ', -50000, '/images/product_1954.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(1955, '11/22 Хурмо 1 кг', -30000, '/images/product_1955.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(1956, '11/23 Хурмо 0,5 кг', -15000, '/images/product_1956.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 5, 1, 0),
(1957, '9/58 Гел концентрат 1000 гр', -42000, '/images/product_1957.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1958, '9/59 Краска  \"Рябина\"  037 Баклажан', 15000, '/images/product_1958.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1959, '9/60 Краска \"Рябина\" 042 Каштановьй', 15000, '/images/product_1959.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1961, '9/61 Краска \"Рябина\" 036 Божоле', 15000, '/images/product_1961_1602760719.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1962, '9/62 Краска \"Рябина\" 035 Гранат', 15000, '/images/product_1962_1602760545.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1963, '4/41 Cгущенное молоко  \"Чутянка\"  920 гр', 17000, '/images/product_1963.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1964, '4/42 Cгущенное молоко  \"Чутянка\" 500 гр', -9000, '/images/product_1964.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1965, '8/11 Майонез \"Махеевь\"  400 гр', -15000, '/images/product_1965_1602758994.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(1966, '8/12 Майонез \"Махеевь\"  200 гр', -7500, '/images/product_1966.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 5, 1, 0),
(1967, '4/45 Тухум Бедана 12шт', 7000, '/images/product_1967.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(1969, '2/18 Котлеты \"Муса\" 300 гр', 16000, '/images/product_1969_1602760470.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(1971, '15/23 Шоколад \"Milky way\" 26 гр', 2500, '/images/product_1971.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1972, '15/24 Шоколад \"M&M\" 45 гр', 7000, '/images/product_1972.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 5, 1, 0),
(1973, '15/26 Шоколад \"Snickers Super\" 95 гр', 8000, '/images/product_1973.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 5, 1, 0),
(1974, '15/27 Шоколад \"Twix Xtra\" 82 гр', 7000, '/images/product_1974.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1975, '9/63 Ленор \"Аромат вдохновленньй\" 910 мл', 25000, '/images/product_1975_1602760671.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1976, '21/31 Совун \"Lux\" 170 гр', 9500, '/images/product_1976.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(1977, '4/48 Порошок \"Eco bell\" 250 гр', 3000, '/images/product_1977.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(1978, '6/13 Гурунч (девзира) Сарик кургон  1 кг', -15000, '/images/product_1978.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(1979, '7/20- Лавровый лист 10 гр', 2000, '/images/product_1979.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1980, '7/21 Кишмиш (ош учун) 50 гр', 2000, '/images/product_1980.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(1985, '16/31 Чой Кора СТС \"Кения\" 88 гр', 8000, '/images/product_1985.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 5, 1, 0),
(1987, '16/32 Чой 95 - 80 гр', -7500, '/images/product_1987.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1992, '16/33 Чой 110 (С9) 200 гр', -6000, '/images/product_1992.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1997, '16/34 Чой 110 (Зип) 400 гр', 18000, '/images/product_1997.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1998, '16/35 Чой (AJDAR) 400 гр', 18000, '/images/product_1998.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(1999, '16/36 Чой 95 400 гр', 18000, '/images/product_1999.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2003, 'Картошка 1 кг', -3500, '/images/product_2003_1602687156.png', 0, 0, 1191, 0, '', 1, NULL, NULL, 5, 1, 0),
(2005, '11/24- Мандарин 1 кг ', 35000, '/images/product_2005.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2006, '11/25 Мандарин 0,5 кг', 17500, '/images/product_2006.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2007, '11/26 Киви 1 кг', 60000, '/images/product_2007.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2008, '11/27 Киви 0,5 кг', 30000, '/images/product_2008.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2009, '10/20 Bonduelle оливки с анчоусом 300г', 22000, '/images/product_2009_1618650907.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2010, '10/21- ASL \"Особая\" тушонка кусковая 325гр', 22000, '/images/product_2010.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2011, '10/22 Говядина (OSIYO) Premium 325 гр', 22000, '/images/product_2011.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2012, '16/37 Ок Канд  (Упаковка 72 шт ) 500 гр', 8000, '/images/product_2012.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2013, '4/46 Сгущенное молоко (Варёное) 340 гр', 7000, '/images/product_2013_1602841283.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(2025, '7/22 Приправа (Rollton) Ош учун 70 гр', 4000, '/images/product_2025.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2026, '7/23 Приправа (Rollton) для курицы 70 гр', 4000, '/images/product_2026.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2027, '7/24 Приправа (Rollton) для мяса 70 гр', 4000, '/images/product_2027.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2028, '21/32 Бальзам (Carbon)', 12000, '/images/product_2028.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2029, '1/31- Чеснок донали ', 2000, '/images/product_2029_1610767140.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 5, 1, 0),
(2035, '18/42 Соса соla 1.5 л \"Shakar siz\"', 10000, '/images/product_2035.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2036, '18/43 Bon aqua 1.5 л газли', -3000, '/images/product_2036.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2037, '18/44 Pepsi 0.250 мл', 4500, '/images/product_2037.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2039, '4/47 Молоко \"Зайка\"  \"Маселка\"', -4500, '/images/product_2039.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2040, '8/13 Майонез \"Маселка\" Провансаль 200 мл', -5000, '/images/product_2040.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(2041, '6/14 Гурунч ( Ок марварид) суюк  1 кг', 10000, '/images/product_2041.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2042, '6/15 Гурунч Лазер  (Тоза) 1 кг', 17000, '/images/product_2042.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2043, '11/28 Олма \"Эрон\"', 40000, '', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2044, '11/29 Мандарин Туркия ', 55000, '', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2046, '7/25 \"Gallina Blanca\" Куриный бульон ', 4500, '/images/product_2046_1615111665.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2047, '21/33 Vanish жидкий пятновыводитель 450 мл 566', 20500, '/images/product_2047.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2049, '21/34 Совун Protex 90 гр  ', 7200, '/images/product_2049.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2050, '10/23- Лосось Kaija 170 gr 569', -20000, '/images/product_2050.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2052, '16/38 Фруктоза 250 г ', -16000, '/images/product_2052.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2053, '9/48 Маргарин ОНА 200 гр', 7000, '/images/product_2053.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2054, '9/49 Маргарин ОНА 250 гр', -8000, '/images/product_2054.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2055, '448 Кондиционер для белья FLO 1л', 24000, '/images/product_2055.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2056, '458 Порошок Лотос Автомат 2,4 кг', 24800, '/images/product_2056.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2057, '458-1 Порошок Лотос  Универсал 2,4 кг', 24800, '/images/product_2057.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2058, '458-0 Порошок Лотос 350 гр Универсал', 4000, '/images/product_2058.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2059, '21/35 Влажные салфетки 15 дона', 2000, '/images/product_2059.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2060, '21/36 Влажные салфетки 25 дона Детские', 4000, '/images/product_2060.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2061, '21/37 Влажные салфетки 25 дона For Mеn', 4500, '/images/product_2061.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2062, '21/38 Влажные салфетки 25 дона For Woman', 4500, '/images/product_2062.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2064, '23/1 \"Bella Panty Soft deo fresh\" 50+10 шт  ', 25000, '/images/product_2064.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2065, '816-20 \"Bella Panty Soft deo fresh\" 20шт ', 10000, '/images/product_2065.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2066, '20/09 Bella Herbs Panty  (лечебнье травы) 60 шт', 18000, '/images/product_2066.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(2067, '23/2 Bella Herbs Panty (лечебнье травы) 20 шт', 7500, '/images/product_2067.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2068, '23/3 Традиционнье прокладки \"Bella NOVA\"10 шт', 10000, '/images/product_2068.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2069, '23/4 \"Bella Nova Maxi\"  10 шт', 14000, '/images/product_2069.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2070, '23/5 Традиционнье Bella Nova Deo Fresh 10шт', 10000, '/images/product_2070.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2071, '23/6 \"Bella Classic Nova Maxi drainette\" 10 шт', 15000, '/images/product_2071.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2072, '23/7 \"Bella Perfecta Night silky drai\" 7 шт', 13000, '/images/product_2072.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2073, '23/8 \"Bella Cotton\" косметические диски 80 шт  ', 8500, '/images/product_2073.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2074, '23/9 \"Bella Cotton\" косметические диски 120 шт', 11500, '/images/product_2074.png', 1, 0, 3827, 0, '', 1, NULL, NULL, 0, 1, 0),
(2075, '21/39 Шампунь для волос \"Прелесть Био\" 500 мл', 13500, '/images/product_2075.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2076, '21/41 Лак для волос \"Прелесть\" 160 мл', 12000, '/images/product_2076.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2077, '459 Гигиеническое \"Чистин Санитарньй\" 750 гр', 17500, '/images/product_2077.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2078, '460 Гигиеническое \"Чистин\" 3в1 750 гр', 17500, '/images/product_2078.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2079, '14/1 Гигиеническое \"Чистин\" Гель 750 гр', 17500, '/images/product_2079.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2080, '462 Гигиеническое \"Чистин\" Универсал 750 гр', 17500, '/images/product_2080.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2081, '463 Отбеливающее \"Чистин\" Омега без хлора 950 гр', 19000, '/images/product_2081.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2082, '464 Комплексньй \"Чистин\"Белизна\"гель 950 гр', 19000, '/images/product_2082.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2083, '465 Очистка канализационньх труб \"Чистин\" 500 гр', 13500, '/images/product_2083.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2084, '466 Накипи в стир машинах \"Чистин\" Эффект 500 гр', 16500, '/images/product_2084.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2085, '467 \"Большая стирка\" Удаление накипи 500 гр', 22000, '/images/product_2085.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2086, '468 Порошок чистящий \"Чистин\" 400 гр', 7000, '/images/product_2086.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2087, '426 Порошок \"Ушастьй Нянь\"  800гр', 22000, '/images/product_2087.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2088, '426 Порошок \"Ушастьй Нянь\"для детского 2,4кг ', 60000, '/images/product_2088.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2089, '426 Порошок \"Ушастьй Нянь\"для детского 4,5 кг', 103000, '/images/product_2089.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2100, '18/45 Chortoq 0.33л', 6500, '/images/product_2100.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2101, '18/46 Chortoq 0.5 л', 7500, '/images/product_2101.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2102, '4/50 Cгущенное молоко 480 гр', 11000, '/images/product_2102.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2103, '4/51 Cгущенное молоко 900 гр', 17000, '/images/product_2103.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2104, '4/52 Cгущенное молоко \"Ичня\" 900 гр', 19000, '/images/product_2104.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(2112, '21/42 Туалетная Бумага Esty 1 пачка', 14000, '/images/product_2112.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2113, '10/24- Ананас кольцами в сиропе 560 гр', -22000, '/images/product_2113.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2114, '10/25- TORRENT Зайтун яшил 350 гр', -16000, '/images/product_2114.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2115, '10/26 TORRENT Зайтун кора 350 гр', -16000, '/images/product_2115.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2117, '12/24 OREO печеные шоколадный 228 гр', 18000, '/images/product_2117.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2118, '16/39 Какао Mix fix  375 гр', -25000, '/images/product_2118.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2120, '16/40 TORA BIKA Cappuccino', 2500, '/images/product_2120.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 5, 1, 0),
(2121, '4/53 Йогурт \"Bio Баланс\" 1 шт', -6500, '/images/product_2121.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2122, '14/2 Наполеон (катта коробка)', 80000, '/images/product_2122.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2123, '14/3- Контик 1 дона пироженное', 8000, '/images/product_2123.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2124, '14/4 Причуда 1 дона пироженное', 8000, '/images/product_2124.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2125, '14/5 Нафис 1 дона пироженное', 8000, '/images/product_2125.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2126, '14/6 Чак Чак (упаковка)', 20000, '/images/product_2126.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2127, '14/7 Подушка (упаковка)', 20000, '/images/product_2127.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2128, '14/8 Опера 1 дона пироженное', 8000, '/images/product_2128.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2129, '14/9 Ката 1 дона пироженное', 8000, '/images/product_2129.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2130, '14/10 Ириска 1 дона пироженное', 9000, '/images/product_2130.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2131, '14/11 Блек жек 1 дона пироженное', 9000, '/images/product_2131.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2132, '14/12Сникерс 1 дона пироженное', 9000, '/images/product_2132.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2133, '14/13 Шоколадный торт (8 кишилик)', 150000, '/images/product_2133.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2134, '14/14 Болалар торти (6 кишилик)', 80000, '/images/product_2134.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2135, '14/15 Сливочный торт (8 кишилик)', 100000, '/images/product_2135.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2136, '14/16 Наполеон (кичик коробка)', 32000, '/images/product_2136.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2137, '14/17 Медовик (коробка)', 32000, '/images/product_2137.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2138, '14/18 Рогалики (коробка)', 32000, '/images/product_2138.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2139, '14/19 Кекс 1 дона', 10000, '/images/product_2139.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2140, '14/20 Мини торт (4 кишилик)', 40000, '/images/product_2140.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2141, '14/21 Шоколад торт (8 кишилик)', 100000, '/images/product_2141.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2142, '14/22 Сливочный торт (6 кишилик)', 80000, '/images/product_2142.png', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2144, '11/30 Олма \"Кук\" 1 кг', 16000, '/images/product_2144.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 5, 1, 0),
(2145, '24/31 Подгузники Pampers aktif bebek 5/ 20', 60000, '/images/product_2145.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2146, '10/27 Грибы шампиньоны 1 лт ', 33000, '/images/product_2146.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2147, '10/28 Грибы шампиньоны 0,5 лт ', 18000, '/images/product_2147.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2149, '16/41 BETA Caffito 3/1 25 пакетов + КРУЖКА ', -27000, '/images/product_2149.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2159, '2/19 \"SHERIN\" Дудланган гушти вакуумда', 35000, '/images/product_2159.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2160, '2/20 Тухтаниёз ота Гушт ( дудланган )', 27000, '/images/product_2160.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2161, '2/21 Дудланган товук гушти ', 22000, '/images/product_2161.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2163, '4/54 \"ФИТАКСА\" брынза 200г ', 40000, '/images/product_2163_1618641389.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2165, '4/55 \"ALSAFI \"Сыр  \"MOZZARELLA\" 400 гр ', 30000, '/images/product_2165.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2166, '19/1 Сырок \"UMKA\"  клубничный', -1800, '/images/product_2166.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(2167, '19/2 Сырок \"UMKA\" ', -1800, '/images/product_2167.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(2169, '10/29- МУРАББО Анжирли 430гр ', -13000, '/images/product_2169.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2170, '10/30 МУРАББО Малина 430 гр ', -13000, '/images/product_2170.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2171, '16/42 Соло прима (курук сут) 500гр ', 22500, '/images/product_2171.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2172, '16/43 BAYCE кук 100 шт пакетчали ', 20000, '/images/product_2172.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2173, '16/44 BAYCE кора 100 шт пакетчали ', 20000, '/images/product_2173.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2176, '24/32 Подгузники Prima aktif bebek 4/27', 60000, '/images/product_2176_1602860315.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2177, '15/28 Шоколад  \"Сладкое\" 1 кг ', 35000, '/images/product_2177.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2180, '15/29 Шоколад Аленка РОССИЯ 1 кг ', 85000, '/images/product_2180.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2181, '18/47 Chortoq 1.0л', 9000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2183, '\"SHERIN\" копчёная колбаса 1 палка', 21000, '/images/product_2183.png', 0, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2184, '2/23 \"ANDALUS\" \"Докторская GOLD\" в/колбаса 1 палка', 44990, '/images/product_2184.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2185, '21/43 Совун \"Olivia\" 140 гр', 6000, '/images/product_2185.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2188, '24/33 Каша NUPPI  1 C Рождения до 6 месяцев ', 41000, '/images/product_2188.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2189, '24/34 Каша NUPPI  2 С 6 до 12 месяцев ', 41000, '/images/product_2189.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2190, '13/17 \"Джинн\" Семечки 250гр', 15000, '/images/product_2190.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2191, '13/18 \"Джинн\" Семечки 70 гр тузли ', 4500, '/images/product_2191.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2192, '13/19 \"Джинн\" Семечки 35 гр тузли ', 2500, '/images/product_2192.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2193, '13/20- \"Мастер жарки\" Семечки 35 гр ', 1500, '/images/product_2193.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2195, '479 AS Отбеливатель 1 лт ', 5000, '/images/product_2195.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2196, '480 Фольга газ учун 1 дона  ', 5000, '/images/product_2196.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2198, '15/Шоколадлар ва қантлар', 0, '/images/product_2198_1609142319.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2199, '15/30 Победа \"Сердечки\" 1 кг ', 85000, '/images/product_2199.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2200, '15/31 Победа \"Сердечки\" 1 кг ', 85000, '/images/product_2200.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2203, '15/32 Крекер \"FUNNY FISHES\" 180 гр', 5500, '/images/product_2203.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2204, '15/33 Детское печенье \"БОНДИ\" 180 гр', 7000, '/images/product_2204.png', 0, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2206, '15/34 ZAINI (ИТАЛИЯ) ASSORTED CHOCOLATES 1 кг ', 156000, '/images/product_2206.png', 0, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2208, '15/35 ZAINI (ИТАЛИЯ) LATTE FONDENTE 1 кг ', -142500, '/images/product_2208.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2209, '15/36 ZAINI ИТАЛИЯ CREMENI 3LAYERS CHOKOLATE 1 кг ', 156000, '/images/product_2209.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2210, '15/37 BELETTI (ИТАЛИЯ) CREMINO NOCCIOLA 1 кг ', 187500, '/images/product_2210.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2211, '15/38 КОНФЕТЫ (РОССИЯ) АТАГ ГОЛД 1кг ', 85000, '/images/product_2211.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2212, '15/39 MIESZKO (ПОЛЬША) \"PLUM IN CHOCOLATE\" 1КГ', 120000, '/images/product_2212.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2213, '15/40 ZAINI (ИТАЛИЯ) \"COMPLIMENTS ASSORTED\" 1К', 110000, '/images/product_2213.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2214, '15/41 SOBRANIE (РОССИЯ) \"BUCHERON MINI\" 1КГ', 120000, '/images/product_2214.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2215, '15/43 КОНФЕТЫ ЖАКО (РОССИЯ) \"ТРУФЕЛИ\" 1КГ', 102900, '/images/product_2215.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2216, '15/46 HAMLET (БЕЛЬГИЯ) \"ASSORTED CHOCOLATES\" 1КГ', 77000, '/images/product_2216.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2218, '15/47 КОНФЕТЫ MIESZKO \"FRENCH TRUFFLES\" 175 ГР', 19500, '/images/product_2218.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2221, '15/48 РУЛЕТ \"МАСТЕР ДЕСЕРТ\" 175 ГР', -7000, '/images/product_2221.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2222, '15/49 РУЛЕТ ХАРЬКОВ ФИРМЕННЫЙ 290 ГР', -10200, '/images/product_2222.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2223, '15/50 ПЕЧЕНЬЕ \"ЗООЛОГИЧЕСКОЕ\" 180 ГР', 4800, '/images/product_2223.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2224, '15/51 ПЕЧЕНЬЕ \"ЗООЛОГИЧЕСКОЕ\" 300 ГР', 9000, '/images/product_2224.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2225, '18/48 Олтиарик 1 лт ', 2000, '/images/product_2225.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2226, '18/49 Tropic KIWI 500ml', 5000, '/images/product_2226.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2227, '18/50 \"Кизилтепа\" негазированная 5лт', 6000, '/images/product_2227.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2228, '18/51 Сок VIKO ', 10000, '/images/product_2228.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2229, '15/52 Конфеты памадка желе 1 кг ', 26500, '/images/product_2229.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2230, '15/53 Конфеты Vanilla Dreams 1 кг ', 45000, '/images/product_2230.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2231, '15/54 Конфеты Лакомка 1 кг ', 51500, '/images/product_2231.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2232, '15/55 Конфети Золотая кувшинка 1 кг ', 39500, '/images/product_2232.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2233, '15/56 Конфеты Golden Lily 1 кг ', 39500, '/images/product_2233.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2234, '15/57 Конфеты Mone 1кг', 54900, '/images/product_2234.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2235, '15/58 Конфеты Milky Way 1 кг ', 75900, '/images/product_2235.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2236, '15/59- Конфеты Nesguik 1кг ', 70000, '/images/product_2236.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2237, '15/60 Конфеты Трюфельный крем 1 кг ', 77000, '/images/product_2237.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2238, '15/61 Конфеты Марсианка 1 кг ', 49000, '/images/product_2238.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2239, '15/62 Конфеты Трюфель 1 кг ', 108000, '/images/product_2239.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2240, '15/63 Конфеты Kreamo 1кг ', 82750, '/images/product_2240.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2241, '15/64 Конфеты Степ 1 кг ', 49900, '/images/product_2241.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2242, '15/65 Конфеты Сладонеж Трюфель 1 кг ', 53000, '/images/product_2242.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2243, '15/66 Конфеты Молочно Шоколадно вафельные 1 кг ', 35300, '/images/product_2243.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2244, '15/67 Конфеты Птица Счастья 1 кг ', 87000, '/images/product_2244.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2245, '15/68 Конфеты Соната 1 кг', 68500, '/images/product_2245.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2246, '15/69 Конфеты Мишки в лесу 1 кг', 77300, '/images/product_2246.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0);
INSERT INTO `products` (`id`, `name`, `price`, `image`, `partner_id`, `group`, `parent_id`, `type`, `comments`, `active`, `date_created`, `options`, `rating`, `status`, `discount`) VALUES
(2247, '15/70 Конфеты Ну-ка отними 1 кг ', 72000, '/images/product_2247.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2248, '15/71- Конфеты Красный Октябрь 1 кг ', 88300, '/images/product_2248.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2249, '15/72 Конфеты Красная шапочка 1 кг ', 62000, '/images/product_2249.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2250, '15/73 Конфеты Аленка 1 кг ', 61800, '/images/product_2250.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(2251, '15/74 Конфеты Супер 1 кг ', 45400, '/images/product_2251.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2252, '15/75- Конфеты Алтин Кум 1 кг ', 53900, '/images/product_2252.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2253, '15/76 Конфеты HYPER 1кг', 52200, '/images/product_2253.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2254, '15/77 Конфеты АРФА 1 кг ', 82800, '/images/product_2254.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2255, '15/78- Конфеты Couturier 1кг', 80000, '/images/product_2255.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2256, '15/79 Конфеты Sweet 1кг ', 75800, '/images/product_2256.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2257, '15/80 Конфеты Fresh 1 кг ', 79200, '/images/product_2257.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2258, '15/81 Конфеты Мишка Косолапый 1 кг', 89000, '/images/product_2258.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2259, '15/82 Конфеты Бархат ночи 1 кг ', 90000, '/images/product_2259.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2260, '15/83- Конфеты с целым фундуком 1 кг ', 91200, '/images/product_2260.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2261, '15/84 Конфеты Фигурный Бочонок 1 кг ', 48950, '/images/product_2261.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2262, '15/85 Конфеты Барилотто 1 кг ', 49100, '/images/product_2262.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2263, '15/86 Конфеты Creamo 1кг ', 75600, '/images/product_2263.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2264, '15/87 Конфеты Baritone 1кг ', 45000, '/images/product_2264.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2265, '15/88 Конфеты Прихоть 1 кг ', 30000, '/images/product_2265.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2266, '15/89 Конфеты 1 кг ', 32000, '/images/product_2266.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2267, '15/90 Конфеты Чио Рио 1 кг ', 50000, '/images/product_2267.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2268, '15/91 Конфеты Шарм 1 кг ', 72000, '/images/product_2268.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2269, '15/92 Конфеты Бурундучок 1 кг ', 38500, '/images/product_2269.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2270, '15/93 Конфеты Княжеские сладости 1 кг', 60000, '/images/product_2270.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 5, 1, 0),
(2271, '15/94 Конфеты Trufalie 1 кг ', 57000, '/images/product_2271.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2272, '15/95 Конфеты Глейс 1 кг ', 26500, '/images/product_2272.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2273, '15/96 Конфеты Versailles 1 кг ', 35000, '/images/product_2273.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2274, '15/97 Конфеты Мадам Мако 1 кг ', 62000, '/images/product_2274.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2275, '15/98 Конфеты TIMI 1 кг ', 40000, '/images/product_2275.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2277, '15/99 Конфеты Сласть 1 кг ', 36800, '/images/product_2277.png', 1, 0, 2198, 0, '', 1, NULL, 'L(text=Маҳсулот миқдори)\nO(text=250 гр;price=*0.25)\nO(text=500 гр;price=*0.5)\nO(text=1 кг;price=*1;checked=1)', 0, 1, 0),
(2278, '24/35 Подгузники Taffi 4/58', -102000, '/images/product_2278.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2279, '24/36 Подгузники Taffi 5 / 42', 105000, '/images/product_2279.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2280, '24/37 Каша Nestogen 3 ли 350 гр', 53500, '/images/product_2280.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2281, '24/38 Каша Малютка 2 ли 350 гр от 6 до 12', 49500, '/images/product_2281.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2283, '13/21 Семечки \"Мастер жарки\" 140гр', 4500, '/images/product_2283.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2284, '13/22 Семечки \"Мастер жарки\" 70 гр ', 2500, '/images/product_2284.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2285, '5/24 Тесто для пиццы 500 гр ', 11000, '/images/product_2285_1618643274.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2286, '5/25 Тесто слоеное бездрожжевое 500 гр ', 11000, '/images/product_2286_1618643711.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2287, '     Тесто слоеное лепешка с луком 500гр', 11000, '/images/product_2287.png', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(2288, '5/26 Тесто слоеная лепешка 500 гр ', 11000, '/images/product_2288.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2289, '422 Tide ручной 1,8 ', 37000, '/images/product_2289.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2290, '16/45 Кофе BOURBON espresso к/м ', -60000, '/images/product_2290.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2296, '16/46 Кофе BOURBON THE ORGINAL к/м', -49000, '/images/product_2296.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2297, '16/47 Кофе SENATOR к/м ', -46000, '/images/product_2297.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2317, '16/48 Кофе FRESCO ARABICA упаковка к/м', -23000, '/images/product_2317.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2318, '16/49 Кофе FRESCO PLATTI упаковка к/м ', -23000, '/images/product_2318.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2319, '16/50 Кофе черный Парус упаковка 70гр к/м ', -21000, '/images/product_2319.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2320, '16/51 Кофе WOLLINGER 3D 75 гр', -20000, '/images/product_2320.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2321, '16/52 Кофе WOLLINGER 3D 95 гр', -23000, '/images/product_2321.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2322, '16/53 Кофе WOLLINGER IQ 75 гр', -20000, '/images/product_2322.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2323, '16/54 Кофе WOLLINGER IQ 95 гр', -23000, '/images/product_2323.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2324, '5/27 Тесто слоеное \"Муъжиза\" 500 гр', -10000, '/images/product_2324.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2334, '5/28- Петра спагетти 400 гр ', 5000, '/images/product_2334.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2339, '11/31 Майиз 1 кг ', 45000, '/images/product_2339.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2341, '7/26- Уксус 70% ', 2500, '/images/product_2341.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2342, '12/25 Асал ( кием учун )  400 гр ', 4500, '/images/product_2342.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 5, 1, 0),
(2343, '8/14- Соевый соус AMOY 500 гр ', 12000, '/images/product_2343.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(2344, '18/52 Сок Bliss (болалар учун)', 1500, '/images/product_2344.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 5, 1, 0),
(2345, '18/53 Сок UP 125мл ( болалар учун )', 1500, '/images/product_2345.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 5, 1, 0),
(2346, '7/27 Салат тузи 200+гр ', 5000, '/images/product_2346.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2347, '18/54 Чой Smile 0.5 ', 3000, '/images/product_2347.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2350, '16/Чой-Кофе-шакар ', 0, '/images/product_2350_1617351047.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2358, '8 LAMBRE гел+пилинг + маска 80 мл Франция ', 88000, '/images/product_2358.png', 2, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2375, '14/23 Наполеон 1 дона ', 8000, '', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(2393, '17/Асаллар', 0, '/images/product_2393_1617351361.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2394, '12/26 American Cookies 180 гр', 9500, '/images/product_2394.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2395, '12/27- Belgium Cookies Apricot  180 гр ', 8500, '/images/product_2395.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2396, '12/28- Belgium Cookies Dark 180 гр ', 9500, '/images/product_2396.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2397, '12/29- Belgium Cookies Raspberry 180 гр ', 9500, '/images/product_2397.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2398, '12/30- Belgium Cookies  180 гр ', 9500, '/images/product_2398.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2399, '15/100 Go Up wafers Bar ', 1800, '/images/product_2399.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2400, '12/31- Hi Mama 180 гр', -8000, '/images/product_2400.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2401, '12/32- Oatmeal Cookies 180 гр ', -6000, '/images/product_2401.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2402, '12/33- Peanut Cookies 180 гр ', -5500, '/images/product_2402.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2404, '12/34- Клубничные вафли пломбир ', 4500, '/images/product_2404.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2405, '12/35- Вафли лимон ', 4500, '/images/product_2405.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2406, '12/36- Вафли сливочный десерт 142 гр  ', 4500, '/images/product_2406.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2407, '12/37 Вафли шоколадный крем 142 гр ', 5000, '/images/product_2407.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2408, '12/38 Вафли малиновый пломбир  142 гр ', 4500, '/images/product_2408.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2416, '15/101- Шоколад Золотая лилия 1 кг ', 40000, '/images/product_2416.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2417, '422 Tide ручной 400 гр ', 12000, '/images/product_2417.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2418, '422 Tide автомат 400 гр ', 13000, '/images/product_2418.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2419, '963- Фольга ', 7750, '/images/product_2419.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2420, '789- Бумага для выпечки ', 7500, '/images/product_2420.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 5, 1, 0),
(2421, '481 Сим щётка пачка 12 та ', 7000, '/images/product_2421.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2422, '481-1 Сим щётка 1 та ', 1000, '/images/product_2422.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2423, '18/55 Himolife 5 л', -6000, '/images/product_2423.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2424, '18/56 Himolife 10 л', -10000, '/images/product_2424.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2425, '12/39- Вафли сливочный орех 142 гр ', 4500, '/images/product_2425.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2429, '15/102 Marshmallow Minus ', 5500, '/images/product_2429.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2430, '15/103 Amilov Premium (молочный) 100гр', 10000, '/images/product_2430.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2431, '15/104 Marshmallow Jumbo', 5500, '/images/product_2431.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2432, '15/105 Amilov Milk chocolate ( молочный) 100 гр', 8000, '/images/product_2432.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2434, '15/106 Amilov Milk chocolate with hazelnuts 1 Кг', 9000, '/images/product_2434.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2437, '15/107 Marshmallow Cables ', 5500, '/images/product_2437.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2440, '15/108 Air Milk Chokolate ', 8000, '/images/product_2440.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2442, '15/109 Air Dark Chokolate', 8000, '/images/product_2442.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2443, '15/110 Shapito (Двухцветное)', 4500, '/images/product_2443.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2445, '15/111Amilov 2x2 (молочный с нач) 500 гр ', 35000, '/images/product_2445.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 5, 1, 0),
(2447, '15/112 Peach and Vanilla ', 15500, '/images/product_2447.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2449, '15/113 Uzbekistan Milk chocolate (молочный) ', -8500, '/images/product_2449.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2450, '15/114 Amilov 2x2 (темный с нач ) 500 гр ', 35000, '/images/product_2450.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2452, '15/115 Uzbekistan Dark chokolate (темный )', -8500, '/images/product_2452.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2453, '15/116 Gummy Bears (фруктовый микс) 70 гр', -4000, '/images/product_2453.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2455, '15/117 Amilov Premium Dark (темный )', 10000, '/images/product_2455.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2458, '15/118 Orange and vanilla ', 18000, '/images/product_2458.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2459, '15/119 Amilov Dark chocolate (темный)', 6000, '/images/product_2459.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2460, '15/120 Marshmallow Lovely ', 5500, '/images/product_2460.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2461, '482 Дельфин губка 5 шт', 6000, '/images/product_2461.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2462, '7/28 Дрожжи \"Ангел\" 45 гр ', 3500, '/images/product_2462.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2463, '5/29- Манпар MAKIZ 400гр ', 7000, '/images/product_2463.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2464, '5/30 Тесто сомса хамири 500 гр ', 11000, '/images/product_2464_1618644059.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2465, '964-1Стакан одноразовый (каттаси) 25та ', 8000, '/images/product_2465.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2466, '965-Стакан одноразовый (кичик) 25та ', 7000, '/images/product_2466.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2468, '967- Тарелка одноразовая (кичик) 25 та', 10000, '/images/product_2468.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2469, '968- Ложечка одноразовая 100 та ', 9000, '/images/product_2469.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2470, '969- Кабоб учун чуп ', 4000, '/images/product_2470.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 5, 1, 0),
(2471, '18/Ичимликлар', 0, '/images/product_2471_1617351492.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2474, '431-DURU 140 гр', 5500, '/images/product_2474.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2475, '24/39 Подгузники Pampers active bebek 5/ 1', 2750, '/images/product_2475.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2477, '422 Tide 400 гр детский  ', 13000, '/images/product_2477.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2478, '483 Белизна 1 лт ', 11000, '/images/product_2478.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2479, '4/58 Сметана \"Садаф\" 20% 500 мл ', 7000, '/images/product_2479.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2480, '4/59 Катик \'Садаф\" 1 лт ', 9000, '/images/product_2480.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2481, '4/60 Био кефир 450 гр \"Садаф\" ', 4500, '/images/product_2481.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2482, '4/61 Творог 360 гр \"Садаф\"', 11000, '/images/product_2482.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2483, '4/62 Айрон 1 лт \"Садаф\"', -12000, '/images/product_2483.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2485, '11/32 Банан 1 кг ', 26000, '/images/product_2485.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2486, '8/15 \" Азифуд \" Чили Соус  ', 8000, '/images/product_2486.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(2487, '21/44 \"Ilgaz\" Антисептическая вода ', 9500, '/images/product_2487.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2488, '4/64 Cгущенное молоко с сахаром ', 18000, '/images/product_2488_1602859766.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2489, '970- Супурги 1та ', 14000, '/images/product_2489.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 5, 1, 0),
(2490, '971- Исирик 1 бог ', 2000, '/images/product_2490.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 1, 1, 0),
(2491, '7/29 Крахмал картофельный', 1500, '/images/product_2491.png', 0, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2492, '12/40 Вафли \"Рокки Кроки\" 300г', -8000, '/images/product_2492.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2494, '12/41 Вафли \"Рокки Кроки\" мини 150г', -4500, '/images/product_2494.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2496, '18/57 \"Наш сад\"   сок яблочный', 8000, '/images/product_2496.png', 1, 0, 2471, 0, '1л', 1, NULL, NULL, 0, 1, 0),
(2497, '18/58 \" J+ \" сок апельсиновый', -8000, '/images/product_2497.png', 1, 0, 2471, 0, ' 1л', 1, NULL, NULL, 0, 1, 0),
(2500, '18/59 \"Jesco\"  энергетический напиток', 3000, '/images/product_2500.png', 1, 0, 2471, 0, ' 0.5 л', 1, NULL, NULL, 0, 1, 0),
(2504, '15/121- \"Jesco\" плитка шоколад ', 4200, '/images/product_2504.png', 1, 0, 2198, 0, '100г', 1, NULL, NULL, 0, 1, 0),
(2505, '18/60 \"Else tea\" холодный чай', -2500, '/images/product_2505.png', 1, 0, 2471, 0, '0.5 л', 1, NULL, NULL, 0, 1, 0),
(2510, '18/61 \"Jesco\"  сок яблоко  250 мл', 2500, '/images/product_2510.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2514, '12/42 \"Jesco\" печенье сахарное с молочным вкусом', -2000, '/images/product_2514.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2516, '18/62 \"Наш сад\"   сок вишнёвый', 8000, '/images/product_2516.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2517, '18/63 \"Наш сад\"   сок мультифруктовый', 8000, '/images/product_2517.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2518, '18/64 \"Наш сад\"   сок ананасовый', 8000, '/images/product_2518.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2519, '18/65 \"Наш сад\"   сок абрикосовый', 8000, '/images/product_2519.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2631, '422 Tide avtomat 1.35кг', 32500, '/images/product_2631.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2632, '8/16 Майонез \"Маселка\" Провансаль 400 мл', -8000, '/images/product_2632.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(2635, '4/66 Cгущенное молоко 1,5л', 25000, '/images/product_2635.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2637, '5/31 Ун Дани высший 25кг', 165000, '/images/product_2637_1602760119.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 3.6666666666666665, 1, 0),
(2638, '12/43 Печенье \"Arabika\" 1 кг', 15000, '/images/product_2638.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2643, '21/45 Зубная паста \"Colgate\" трайное действие 154г', 9000, '/images/product_2643.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2644, '5/32 \"HOT LUNCH\" 90г', 3000, '/images/product_2644.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2645, '5/33 \"HOT LUNCH\" 45г', 1500, '/images/product_2645.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2646, '5/34 Лапша \"XUMO\" 350г', 4200, '/images/product_2646.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2650, '5/35 \"Роллтон\" гнёзда яичные', -8000, '/images/product_2650.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2651, '2/24 \"To`xtaniyoz ota\" краковская 1шт', 21000, '/images/product_2651.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2652, '2/25 Тошкекнт калбаса (охотничьи)', 13000, '/images/product_2652.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2653, '2/26 \"Ташкентские\" колбаса Говяжья ', 7000, '/images/product_2653.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2654, '2/27 \"SHERIN\" сарделки 1 кг', 47500, '/images/product_2654_1602761016.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2656, '4/67 Айрон 400 \"Садаф\"', -7000, '/images/product_2656_1602859428.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 5, 1, 0),
(2657, '812- Пакеты для запекания 8шт', 4500, '/images/product_2657.png', 1, 0, 3825, 0, '25х38', 1, NULL, NULL, 0, 1, 0),
(2659, '21/46 \"FABIENNE\" СОВУН 140г', 5200, '/images/product_2659.png', 1, 0, 3824, 0, 'c витамин', 1, NULL, NULL, 0, 1, 0),
(2661, '485-3 \"Briller\" губка ', 2000, '/images/product_2661.png', 1, 0, 3825, 0, '3 шт', 1, NULL, NULL, 0, 1, 0),
(2663, '4/68 \"EDAMIR\" сыр 1кг', -61000, '/images/product_2663.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2664, '485-5 \"Briller\" губка ', 5000, '/images/product_2664.png', 1, 0, 3825, 0, '10 шт', 1, NULL, NULL, 0, 1, 0),
(2665, '10/31 \"RIGA GOLD\" сильдь филе в масле', 17000, '/images/product_2665.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2666, '15/122 \"NUTLET\" шоколадный паста ', 19000, '/images/product_2666.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2668, '15/123 \"NUTLET\" шоколадная паста', 21500, '/images/product_2668.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2669, '15/124 \"NUTLET\" шоколадная паста', 24000, '/images/product_2669.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2672, '12/44 \"Мини пряники\" c малиновой  начинкой', -6500, '/images/product_2672.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2673, '5-36 \"Oyijonim quymoqlari\" тайёр коришма ', -7000, '/images/product_2673.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2674, '24/40 \"MINISTER\" печенье затяжное', 6000, '/images/product_2674.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(2675, '15/125 \"IBON\" fruit конфеты', 44000, '/images/product_2675.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2682, '12/45 Печенье \"Почемучка\"  1кг', 17000, '/images/product_2682.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 5, 1, 0),
(2683, '5/37 \"Малда хамири\" домашние 2 шт', 10000, '/images/product_2683.png', 1, 0, 1197, 0, '2 шт', 1, NULL, NULL, 5, 1, 0),
(2686, '21/47 Шампунь \"Чистая Линия\" 400мл', 15600, '/images/product_2686.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2687, '3/9- Товук филе 1 кг эко тоза', 40000, '/images/product_2687.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 5, 1, 0),
(2692, '6/16 Манная крупа \"Макиз\"700гр', -15000, '/images/product_2692.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2693, '486 Жидкое мыло  (Natural) 460 гр', 8000, '/images/product_2693.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2696, '2/28 \"SHERIN\" копчёная колбаса', 29000, '/images/product_2696.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2697, '7/29- Дрожжи \"Bakerdraem\" 100 гр', 5000, '/images/product_2697.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2698, '7/30- Дрожжи \"Fariman\" 500гр', 25000, '/images/product_2698.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2700, '15/126 \"Magic\" чёрный шоколад  плитка ', 4000, '/images/product_2700.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2701, '15/127 \"Magic\" белое шоколад плитка', 4000, '/images/product_2701.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2704, '21/48 Совун \"DUBAI\" 90г ', 3300, '/images/product_2704.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2710, '21/49 Совун \"MY Family\" 200г/4 ', -14000, '/images/product_2710.png', 1, 0, 3824, 0, '4шт', 1, NULL, NULL, 5, 1, 0),
(2719, '21/50 Совун \"PALMERA\"  125г', 3400, '/images/product_2719.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2723, '21/51 Совун \"LUCIA\" 130г', 6000, '/images/product_2723.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2724, '21/52 Совун \"TODAY\" 130г', 6000, '/images/product_2724.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2725, '21/53 Совун \"NARCOTIQUE\"  130г', 5000, '/images/product_2725.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2726, '21/54 Совун \"MEN\" 130г', 6000, '/images/product_2726.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2727, '21/55 Совун \"CHANCE CHANEL\" 130г', 5000, '/images/product_2727.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2731, '21/56 Крем для рук \"OLIVA\" 70мл', 4000, '/images/product_2731.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2748, '487 \"WOOM\" очиститель стекол ', 7000, '/images/product_2748.png', 1, 0, 3825, 0, '500мл', 1, NULL, NULL, 5, 1, 0),
(2750, '488 салфетки \"PANDA\"', -1000, '/images/product_2750.png', 1, 0, 3825, 0, '1 шт', 1, NULL, NULL, 0, 1, 0),
(2759, '18/66 \"PEPSI\"  449мл ', 7000, '/images/product_2759.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2761, '3/10- Товук бедро эко тоза 1 кг', 35000, '/images/product_2761.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2762, '21/57 Салфетки \"SOFT CARE\"', 11000, '/images/product_2762.png', 1, 0, 3824, 0, '2 шт', 1, NULL, NULL, 0, 1, 0),
(2765, '4/72 Сыр плавленный \"Ласковое лето\" 350 г', -20000, '/images/product_2765.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2766, '4/73 \"BRAVO PISHLOG\'I \"  сыр 1кг', -43200, '/images/product_2766.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2769, '2/30 \"Sarafroz\" \"Докторская в/колбаса 1 кг', -23000, '/images/product_2769.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2770, '4/74 Сыр Вакуумный \"IBRAHIMBEY\" 1шт', -3500, '/images/product_2770.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2772, '2/31 \"TIM\" сосиски 1 пачка', 10000, '/images/product_2772.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2773, '4/75 \"ALSAFI \"Сыр  \"MOZZARELLA\" 250 гр ', 19000, '/images/product_2773_1602860115.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2774, '15/128 Конфеты ДЖАЗЗИ 1 кг', 31500, '/images/product_2774.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2775, '5/38 \"Роллтон\" 400 гр', 7000, '/images/product_2775.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2776, '5/39 \"Роллтон\" лапша яичная 400 гр', 7000, '/images/product_2776.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(2778, '6/17 Манная крупа \"НАША КАША\" 400гр', -10000, '/images/product_2778.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2779, '10/32- ASL \"ДЕЛИКАТЕС\" тушонка конина 325гр', -28000, '', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2780, '21/58 Шампунь Palmolive 200мл', 14000, '/images/product_2780.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2781, '489 \"WOOM\"  средство для мытья посуды', 2000, '/images/product_2781.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2782, '2/32 Тефтели \"по дамашнему\" 300 гр', 20000, '/images/product_2782_1602761138.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2783, '9/50 Маргарин \"Донна\" 250 гр', 6000, '/images/product_2783.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2784, '18/67 Алое Вера 0.5л', 9000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2785, '18/68 Алое вера 1.5л', 21000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2786, '18/69 \"Sprite\" 250 мл бутылочный', -5500, '/images/product_2786.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2789, '5/40- Ун \"Дани\" высший - 50 кг', 325000, '/images/product_2789_1602860751.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 1, 1, 0),
(2790, '13/23 Чипсы \"Lays STIX\" 125 гр', 12000, '/images/product_2790.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 5, 1, 0),
(2791, '13/24 Чипсы \"Lays STIX\"  65 гр', 7000, '/images/product_2791.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 1, 1, 0),
(2798, '16/55 \"Арабика\" Кофе', -13000, '/images/product_2798.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2799, '2/33 \"To`xtaniyoz ota\" сервелат карона 1шт', -25000, '/images/product_2799.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2801, '2/34 \"To`xtaniyoz ota\"калбаса (охотничьи)', -17000, '/images/product_2801_1614686564.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2802, '2/35 \"To`xtaniyoz ota\"докторская особая', -59000, '/images/product_2802_1614684544.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2804, '2/36 \"To`xtaniyoz ota\" сосиски паласа 1кг', -42000, '/images/product_2804.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2805, '7/31- лимонная кмслота', 1000, '/images/product_2805.png', 1, 0, 1199, 0, '10г', 1, NULL, NULL, 0, 1, 0),
(2806, '490 \"AZUR\" губка 5шт ', -5000, '/images/product_2806.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2808, '4/77 Творог 400 гр (каймок+майиз)', -11000, '/images/product_2808.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2809, '7/32- Разрыхлитель 1 шт', -2000, '/images/product_2809.png', 1, 0, 1199, 0, 'оригинал ', 1, NULL, NULL, 0, 1, 0),
(2810, '11/33 Гура (G`o`ra) 1кг', -12000, '/images/product_2810.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2811, '9/51- \"Хазар\" ёги 0,5кг', 10000, '/images/product_2811.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 5, 1, 0),
(2814, '16/56 Фито чай \"СУПЕР СЛИМ0\"', 20000, '/images/product_2814.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2815, '4/78 \"ФИТАКСА\" брынза 400г ', 40000, '/images/product_2815.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2816, '4/79 \"Мусаффо\" молоко 4%', -9500, '/images/product_2816.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2818, '9/52- Зигир ёги (zig`ir yog`i) 1л', -30000, '/images/product_2818.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2819, '21/59 Шампунь \"Doctors\" 200мл', 12000, '/images/product_2819.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2820, '491 Освежитель Воздуха ', 10000, '/images/product_2820.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2821, '2/37 \"Тухтаниёз ота\" егсиз (варёная колбаса) 1 кг	', -60000, '/images/product_2821.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 5, 1, 0),
(2823, '21/60 \"Чистая линия\" гел для душа', 14500, '/images/product_2823.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2824, '4/80 Сгущенное молоко \"DOREEN\" ', -11000, '/images/product_2824.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2825, '4/81 Сгущенное молоко \"DOREEN\" ', -18000, '/images/product_2825.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2826, '4/82 Сгущенное молоко \"DOREEN\" ', -26500, '/images/product_2826.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2827, '454 Краска \"Рябина\" 053 Черный', 15000, '', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2829, '9/53 Сариёг \"Bon Debut\" 200г', 14000, '/images/product_2829.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2830, '9/54 Сариёг \"Bon Debut\" 500г', 35000, '/images/product_2830.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2832, '21/61 Зубная щетка \"DEMEX\"', 3000, '/images/product_2832.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2833, '21/62 Зубная щетка \"DEMEX\"', 3000, '/images/product_2833.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2834, '16/57 Чой \"ROYAL\" 25 дона', 9000, '/images/product_2834.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2835, '13/25 Джин семечки 50 гр Болшой ', 3500, '/images/product_2835.png', 1, 0, 1545, 0, 'тузли ва тузсиз ', 1, NULL, NULL, 0, 1, 0),
(2837, '21/63 Антисептический спрей Energy', 8000, '/images/product_2837.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2838, '16/58 Кук чой 110 0,5 кг', 15000, '/images/product_2838.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2839, '16/59 Кук чой N-95 0,5кг', 18000, '/images/product_2839.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2840, '13/26 Чипсы \"CHEERS\" 140 гр', 9000, '/images/product_2840.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2841, '12/46 Печенье \"Carnaval\" 1кг', -20000, '/images/product_2841.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2842, '12/47 Печенье \"Carnaval\" 500 гр', -10000, '/images/product_2842.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2843, '10/33- Томат IDEAL (Приправа для блюда) 1лт', -18000, '/images/product_2843.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2844, '15/129 Шоколад \"Кit Каt \" 1 шт ', 9000, '/images/product_2844.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2845, '12/48 печенье алёнка', -8000, '/images/product_2845.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2846, '12/49 Печенье \"Arabika\" 0,5 кг', 8000, '/images/product_2846.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2847, '10/34 ASL \"Премиум\" тушенка кусковая 325гр', -22000, '/images/product_2847.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2848, '9/55 \"Maselko\" халол 500 г', -15000, '/images/product_2848.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2849, '9/56 \"Maselko\" халол 200 г', -6000, '/images/product_2849.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(2850, '11/24 (арабистон) 400гр', -13000, '/images/product_2850.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2851, '11/25 Хурмо \"КОРА\" 1кг', -32000, '/images/product_2851.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2853, '7/33 \"Rollton\" бульон  70 гр', 4000, '/images/product_2853.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(2854, '492 (Grass) \"АРЕНА\" средства для пола', 22000, '/images/product_2854.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2855, '493 (Grass) \"AZELIT\" анти жир', 22500, '/images/product_2855.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2856, '494 (Grass) \"Universal cleaner\" Уни/средство ', 24000, '/images/product_2856.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2857, '16/60 \"OOLONG\" green tea 8810 400г', 33000, '/images/product_2857.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2858, '16/61 \"OOLONG\" green tea 250г', 15000, '/images/product_2858.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2859, '16/62 \"OOLONG\" green tea v333 400г', 33000, '/images/product_2859.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2860, '16/63 \"OOLONG\" green tea 8810 250г', 23000, '/images/product_2860.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2861, '2/38 \"Sarafroz\" \"докторская\"  1кг', 23000, '/images/product_2861_1614684799.png', 1, 0, 1192, 0, 'вор/колбаса особая', 1, NULL, NULL, 0, 1, 0),
(2863, '2/39 \"To`xtaniyoz ota\"докторская', -47000, '/images/product_2863_1614685082.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2864, '11/26- Клубника (Qulupnay)  1кг', -22000, '/images/product_2864.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 5, 1, 0),
(2865, '11/27- Шур данак 1 кг', 25000, '/images/product_2865.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2866, '10/35- ASL \"Премьеро\" тушонка кусковая 325гр', -22000, '/images/product_2866.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2867, '10/36 Говядина тушеная \"ЛЮБИТЕЛСКАЯ\"', -20000, '/images/product_2867.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(2868, '2/40 Salari докторская  1кг', -45000, '/images/product_2868_1614685730.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2871, 'хоставар', 0, '', 2, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2872, '16/64  Какао Nesquik 250 гр', 22000, '/images/product_2872.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2873, '16/65 Кук чой Exclusive 95  500гр ', 22000, '/images/product_2873.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2881, '3/11 Мол гушти 1 кг (буйин)', 70000, '/images/product_2881.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2882, '3/12 Мол гушти 1 кг (буйин) лахм', 88000, '/images/product_2882.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2883, '3/13- Мол гушти 1 кг (сон) ', 70000, '/images/product_2883.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2884, '3/14 Мол гушти 1 кг (сон) лахм', 88000, '/images/product_2884.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2885, '3/15- Мол гушти 1 кг (кул) ', 70000, '/images/product_2885.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2886, '3/16 Мол гушти 1 кг (кул) лахм', 88000, '/images/product_2886.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2887, '3/17- Мол гушти 1 кг (пушти магиз) заказга', 95000, '/images/product_2887.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2888, '3/18- Мол гушти 1 кг (дандана)', 70000, '/images/product_2888.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2889, '3/19- Думба 1 кг ', 75000, '/images/product_2889.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 5, 1, 0),
(2892, '3/20 Мол ёги 1 кг (заказга) ', 20000, '/images/product_2892.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2893, '3/21- Куй ёги (чарви) 1кг', 35000, '/images/product_2893.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(2896, 'Жахон адабиёти', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2897, 'Узбек адабиёти', 1, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2898, 'Бизнес ва психология', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2899, 'На русском', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2900, 'Замонавий узбек адабиёти', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2901, 'Болалар адабиёти', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2902, 'диний адабиёт', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2903, 'Илм-фан ва дарсликлар', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2904, 'Абитуриентлар учун', 0, '', 3, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2905, 'ОФИСНЫЕ ПРИНАДЛЕЖНОСТИ (RASMIY AKSESSUARLAR)', 0, '', 5, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2906, 'ШКОЛЬНЫЕ ПРИНАДЛЕЖНОСТИ (MAKTAB AKSESSUARLARI)', 0, '', 5, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2907, 'ХОЗ/ПРИНАДЛЕЖНОСТИ (MAISHIY AKSESSUARLAR)', 0, '', 5, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2908, 'ДЕТСКОЕ ТВОРЧЕСТВО (BOLALARNING YARATILIShI)', 0, '', 5, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(2918, '495 Super Lux ', -4500, '/images/product_2918.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2921, '18/70 Газ ( Вода ) 1,5 лт ', 5000, '/images/product_2921.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(2927, '11/28- Урик \"Кандак\" (баргек) 300гр', 12000, '/images/product_2927.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2928, '11/29 Урик \"Кандак ирис\" 300гр', 14000, '/images/product_2928.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(2929, '496 Порошок \"Берёзовая Роща\" Ручной 250 гр', 4000, '/images/product_2929.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(2930, '2/41 Дудланган гушт вакум ', -27000, '/images/product_2930.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(2931, '497 AURA Крем-мыло жидкое 500 мл ', 10000, '/images/product_2931.png', 1, 0, 3825, 0, 'Антибактериальное ', 1, NULL, NULL, 0, 1, 0),
(2932, '497-1 AURA  крем мыло жидкое 500 мл ', 10000, '/images/product_2932.png', 1, 0, 3825, 0, 'Морские минералы ', 1, NULL, NULL, 0, 1, 0),
(2935, '21/64 \"Colgate\" 3/действие экстра отбеливание 156г', -11000, '/images/product_2935.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2936, '21/65 \"Colgate\" макс блеск 50г', 14500, '/images/product_2936.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2937, '16/66 IMPRA кук 90 гр', 18000, '/images/product_2937.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2938, '16/67 Чой кора \"Alokazay\" 100 гр ', -17000, '/images/product_2938.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(2939, '15/130 Шоколадная паста Сhococream 200 гр', 14000, '/images/product_2939.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(2943, '13/27 Bio курут (аччик) \"Ermak\" 30 гр ', 4000, '/images/product_2943.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(2945, '17/2 Тог асали 200г', 20000, '/images/product_2945.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2946, '17/3 Тоза пахта асали 200г', 16000, '/images/product_2946.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2947, '17/4 Пахта адир асали 200г', 12000, '/images/product_2947.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2948, '17/5 Седана асали 200г', 14000, '/images/product_2948.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2949, '17/6 Киргизистон. Тог асали 250г', 26000, '/images/product_2949.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2950, '17/7 Янток асали 200г', 12000, '/images/product_2950.png', 1, 0, 2393, 0, '', 1, NULL, NULL, 0, 1, 0),
(2951, '4/83 Сыр Дилбах 1 кг ', 41000, '/images/product_2951.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2952, '710- Дезодарант \"Mennen speed stick\" neutro power ', 18500, '/images/product_2952.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(2953, '4/84 \"Hochland\" плавленый cыр чизбургер', 18000, '/images/product_2953.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(2954, '«Саодат асри қиссалари» китоби', 250000, '/images/product_2954.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 5, 1, 0),
(2955, '«Қуръон - қалблар шифоси» китоби', 60000, '/images/product_2955.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2956, ' «Учдан кейин кеч» китоби (лотин алифбосида)', 35000, '/images/product_2956.png', 3, 0, 2898, 0, 'Боланинг ўрганиш ва ривожланиш салоҳияти энг юксак бўлган давр дастлабки уч йилдир. Фурсатни бой берманг!', 1, NULL, NULL, 0, 1, 0),
(2957, '«Билимсизликнинг шифоси савол» 1-китоблари', 35000, '/images/product_2957.png', 3, 0, 2902, 0, 'Одинахон Муҳаммад Содиқнинг', 1, NULL, NULL, 5, 1, 0),
(2958, '«Билимсизликнинг шифоси савол»2-китоблари', 35000, '/images/product_2958.png', 3, 0, 2902, 0, 'Одинахон Муҳаммад Содиқнинг', 1, NULL, NULL, 0, 1, 0),
(2959, '«Пайғамбарлар тарихи» китоби', 65000, '/images/product_2959.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2960, '«Содиқ саҳобалар қиссаси» китоби', 90000, '/images/product_2960.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2961, '\"Жаннатга йул ёки киёмат хабарлари\" ', -123456, '/images/product_2961.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2962, '\"КУРЪОНИ КАРИМ\"', 200000, '/images/product_2962.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2963, '\"ТАРИХИ МУХАММАДИЙ\" (Алихонтура Согуний)', 190000, '/images/product_2963.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2964, '\"КУРЪОНИ АЗИМ\" МУХТАСАР ТАФСИРИ', 300000, '/images/product_2964.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2965, ' \"ИМОМ БУХОРИЙ ВА ИМОМ МУСЛИМ ... ХАДИСЛАРИ\"', 95000, '/images/product_2965.png', 3, 0, 2902, 0, 'МУТТАФАКУН АЛАЙХ ХАДИСЛАРИ', 1, NULL, NULL, 0, 1, 0),
(2966, '\"МУКАДДАС ОЙЛАР ВА МУСТАЖОБ ДУОЛАР\"', 55000, '/images/product_2966.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2967, '\"МУАЛЛИМИ СОНИЙ\"', 25000, '/images/product_2967.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2968, '\"КУРЪОНИ КАРИМДАН БАЪЗИ СУРАЛАР\"', 15000, '/images/product_2968.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2969, '\"МУАЛЛИМИ СОНИЙ\"', 25000, '/images/product_2969.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 5, 1, 0),
(2970, '\"АРАБ АЛИФБОСИ\"', 20000, '/images/product_2970.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2971, '\"БАХТИЁР ОИЛА\"', 65000, '/images/product_2971.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 5, 1, 0),
(2972, '\"МУКАДДАС ОЙЛАР ВА МУСТАЖОБ ДУОЛАР\"', 30000, '/images/product_2972.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2973, '\"КУРЪОНИ КАРИМ\"', 100000, '/images/product_2973.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 5, 1, 0),
(2974, '\"КУРЪОНИ КАРИМ\"', 450000, '/images/product_2974.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2975, '\"КУРЪОНИ КАРИМ\"', 600000, '/images/product_2975.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2976, '\"КУРЪОНИ КАРИМ\"', 200000, '/images/product_2976.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 5, 1, 0),
(2977, '\"КУРЪОНИ КАРИМ\"', 200000, '/images/product_2977.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2980, '\"МУСУЛМОН УЧУН ЗАРУР БИЛИМЛАР\"', 35000, '/images/product_2980.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2981, '\"АЛЛОХНИНГ ГУЗАЛ ИСМЛАРИ ВА ИСМИ АЪЗАМ\"', 95000, '/images/product_2981.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2982, '\"ИМОМ БУХОРИЙ ВА ИМОМ МУСЛИМ ... ХАДИСЛАРИ\"', 95000, '/images/product_2982.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2983, '\"КИЗЛАРЖОН\"', 25000, '/images/product_2983.png', 3, 0, 2902, 0, 'Одинахон Мухаммад содик', 1, NULL, NULL, 0, 1, 0),
(2984, '\"ИСТИГФОРНИНГ 40 ХОСИЯТИ, САЛОВАТЛАР\"', 35000, '/images/product_2984.png', 3, 0, 2902, 0, '', 1, NULL, NULL, 0, 1, 0),
(2985, '12/50 Ширин кулча 1 кг ', 15000, '/images/product_2985.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2986, '12/51 Ширин кулча 0,5 кг ', 7500, '/images/product_2986.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(2991, '1/33- Картошка  1кг', 4500, '/images/product_2991.png', 0, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(2996, '10/37MB маслины без косточка', -19500, '/images/product_2996.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(3001, '12/52 Печенье  \"Овсянное\" 0,5 гр', -12500, '/images/product_3001.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3002, '12/53 Печенье  \"Овсянное\" 1кг', -23000, '/images/product_3002.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3006, '9/57 \"Пахта Ёги\"', 17000, '/images/product_3006.png', 1, 0, 1201, 0, '', 1, NULL, NULL, 0, 1, 0),
(3008, '16/68 TORA BIKA Cappuccino 20шт', 40000, '/images/product_3008.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 5, 1, 0),
(3009, '19/3 Музкаймок (фруктовый) \"DAZA\" 1000 г', 24000, '/images/product_3009.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3010, '19/4 Музкаймок (сливочный)\"DAZA\"  1000 г', -1800, '/images/product_3010.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3011, '19/5 Музкаймок  (шоколадный) \"DAZA\"1000 г', 24000, '/images/product_3011.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3012, '19/6 Музкаймок (фруктовый) \"DAZA\" 500 г', 12000, '/images/product_3012.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3013, '19/7 Музкаймок (сливочный) \"DAZA\"  500 г', -12000, '/images/product_3013.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3014, '19/8 Музкаймок  (шоколадный) \"DAZA\" 500 г', 12000, '/images/product_3014.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3015, 'Beeline', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3016, 'Uzmobile GOLD (ОЛТИН РАКАМЛАР)', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3017, 'UMS', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3018, 'Ucell GOLD (ОЛТИН РАКАМЛАР)', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3020, '94 442-55-55', 6100000, '/images/product_3020.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3021, '94 586-55-55', 4100000, '/images/product_3021.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3022, '93 988-22-22', 4100000, '/images/product_3022.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3023, '94 933-07-77', 1100000, '/images/product_3023.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3024, '93 035-00-07', 1100000, '/images/product_3024.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3025, '93 044-47-47', 850000, '/images/product_3025.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3026, '93 988-70-70 ', 850000, '/images/product_3026.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3027, '93 075-50-50', 850000, '/images/product_3027.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3028, '93 075-20-20', 850000, '/images/product_3028.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3029, '94 565-07-70', 750000, '/images/product_3029.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3030, '93 820-00-77', 750000, '/images/product_3030.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3031, '93 988-70-07', 350000, '/images/product_3031.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3032, '93 987-00-10', 350000, '/images/product_3032.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3033, '93 987-00-05', 350000, '/images/product_3033.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3034, '94 443-00-05', 350000, '/images/product_3034.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3035, '93 396-09-09', 350000, '/images/product_3035.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3036, '94 392-20-00', 350000, '/images/product_3036.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3037, '93 984-40-00', 350000, '/images/product_3037.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3038, '93 484-40-40', 350000, '/images/product_3038.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0);
INSERT INTO `products` (`id`, `name`, `price`, `image`, `partner_id`, `group`, `parent_id`, `type`, `comments`, `active`, `date_created`, `options`, `rating`, `status`, `discount`) VALUES
(3039, '94 131-40-40', 350000, '/images/product_3039.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3040, 'Ucell ', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3041, '94 ***-**-**', 10000, '/images/product_3041.png', 6, 0, 3040, 0, '', 1, NULL, NULL, 0, 1, 0),
(3042, '93 ***-**-**', 10000, '/images/product_3042.png', 6, 0, 3040, 0, '', 1, NULL, NULL, 0, 1, 0),
(3043, '94 442-80-80', 350000, '/images/product_3043.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3044, '93 373-01-10', 180000, '/images/product_3044.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3045, '94 393-01-11', 180000, '/images/product_3045.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3046, '94 447-01-11', 180000, '/images/product_3046.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3047, '94 449-01-11', 180000, '/images/product_3047.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3048, '93 737-00-20', 180000, '/images/product_3048.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3049, '94 443-02-20', 180000, '/images/product_3049.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3050, '93 393-03-30 ', 180000, '/images/product_3050.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3051, '94 441-40-04', 180000, '/images/product_3051.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3052, '94 447-40-04', 180000, '/images/product_3052.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3053, '94 557-40-04', 180000, '/images/product_3053.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3054, '93 970-04-44', 180000, '/images/product_3054.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3055, '94 399-04-44 ', 180000, '/images/product_3055.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3056, '94 399-05-55', 180000, '/images/product_3056.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3057, '93 985-05-00', 180000, '/images/product_3057.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3058, '93 644-05-50', 180000, '/images/product_3058.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3059, '94 442-05-50', 180000, '/images/product_3059.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3060, '94 393-50-05', 180000, '/images/product_3060.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3061, '93 484-05-55', 180000, '/images/product_3061.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3062, '94 393-05-55', 180000, '/images/product_3062.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3063, '93 979-05-55', 180000, '/images/product_3063.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3064, '94 139-09-99', 180000, '/images/product_3064.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3065, '94 499-00-50', 180000, '/images/product_3065.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3066, '93 984-00-70', 180000, '/images/product_3066.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3067, '94 499-00-90', 180000, '/images/product_3067.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3068, '94 137-19-97', 60000, '/images/product_3068.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3069, '94 448-19-97', 60000, '/images/product_3069.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3070, '94 491-19-97', 60000, '/images/product_3070.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3071, '94 553-19-97', 60000, '/images/product_3071.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3072, '94 441-19-98', 60000, '/images/product_3072.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3073, '94 557-20-04', 60000, '/images/product_3073.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3074, '94 447-12-34', 60000, '/images/product_3074.png', 6, 0, 3018, 0, '', 1, NULL, NULL, 0, 1, 0),
(3075, '24/41 Подгузники BUMBLE baby 4/60 дона', 99000, '/images/product_3075.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3076, '24/42 Подгузники BUMBLE baby 4/1 дона', 1700, '', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3082, '19/9 Музкаймок Пломбир на сливках DAZA 400 гр ', -9500, '/images/product_3082.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3083, '19/10 Музкаймок Лидер 85 гр  ', 2500, '/images/product_3083.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3084, '19/11 Музкаймок  Клубничный чизкейк 200 гр ', 6000, '/images/product_3084.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3086, '1/34- Гул карам 1 дона ', 3000, '/images/product_3086.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3087, '11/30- Гилос (Gilos) 1 кг ', -15000, '/images/product_3087.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3088, '11/31 Гилос (Gilos) 0.5 кг ', -8000, '/images/product_3088.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3089, 'Uzmobile ', 0, '', 6, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3090, '99 497-**-**', 10000, '/images/product_3090.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 5, 1, 0),
(3091, '99 049-**-**', 10000, '/images/product_3091.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 0, 1, 0),
(3092, '99 982-**-**', 10000, '/images/product_3092.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 0, 1, 0),
(3093, '99 897-**-**', 10000, '/images/product_3093.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 0, 1, 0),
(3094, '99 524-**-**', 10000, '/images/product_3094.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 0, 1, 0),
(3095, '99 493-**-**', 10000, '/images/product_3095.png', 6, 0, 3089, 0, '', 1, NULL, NULL, 0, 1, 0),
(3096, '99 ***-**-** категория 9', 99999, '/images/product_3096.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3097, '99 ***-**-** категория 8', 199999, '/images/product_3097.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3098, '99 ***-**-** категория 7', 399999, '/images/product_3098.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3099, '99 ***-**-** категория 6', 599999, '/images/product_3099.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3100, '99 ***-**-** категория 5', 1199999, '/images/product_3100.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3101, '99 ***-**-** категория 4', 1999999, '/images/product_3101.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3102, '99 ***-**-** категория 3', 3999999, '/images/product_3102.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3103, '99 ***-**-** категория 2', 11999999, '/images/product_3103.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3104, '99 ***-**-** категория 1', 19999999, '/images/product_3104.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 0, 1, 0),
(3105, '99 ***-**-** категория 0', 39999999, '/images/product_3105.png', 6, 0, 3016, 0, '', 1, NULL, NULL, 5, 1, 0),
(3108, '15/131 \"sorini ovetti fantasia\" 1кг', 125000, '/images/product_3108.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3109, '15/132 \"АТАГ ГОЛД\" 1кг', 79000, '/images/product_3109.png', 0, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3110, '14/24Лимонли 1 дона ', -5000, '', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(3111, '14/25 Тварожний 1 дона ', 5000, '', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(3112, '3/22- Дум 1 кг 2 кг дан 3 кг гача ', 55000, '', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3115, '973- \"МЕЧТА ХОЗЯЙКИ\" Кришки для консерва', 18000, '/images/product_3115.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3116, '18/71 Dinay напиток 0,5л', 5000, '/images/product_3116.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3117, '18/72 Айс теа 0,5 л', 3000, '/images/product_3117.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3118, '18/73 Montella sweet 0.5л', 2000, '/images/product_3118.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3119, 'Косметика и Парфюмерия', 0, '', 8, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3120, 'Атир  \"CHERISH\" 50мл women ', 105000, '/images/product_3120.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3121, '\"AMOR DIA\" made in dubai     100ml', 130000, '/images/product_3121.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3122, '\"3 D&D pour femmi\" women made in dubai   100ml', 130000, '/images/product_3122.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3123, '\"ECLAT LA violetti\" made in dubai  100ml', 125000, '/images/product_3123.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3124, 'BABUS GARDEN 100ml', 130000, '/images/product_3124.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3125, 'REAL LOVE in WHITE 100ml', 130000, '/images/product_3125.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3126, 'B MINE 100ml', 220000, '/images/product_3126.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3127, 'ELIGE 50ml', 190000, '/images/product_3127.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3128, 'SHEIK 100ml', 135000, '/images/product_3128.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3129, 'CHANGE DE CANAL 100ml', 130000, '/images/product_3129.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3130, 'feberlic \"Vant d`Aventures\" MAN 100ml', 150000, '/images/product_3130.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3131, 'CLOY   WOMAN 100ml', 130000, '/images/product_3131.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3132, 'LOVE SENSATION WOMAN 100ml', 135000, '/images/product_3132.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3133, 'faberlic \"MON ROI\" MAN 100ml', 170000, '/images/product_3133.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3134, 'RICH GIRL  WOMAN 90ml', 290000, '/images/product_3134.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3135, 'PINK DRESS WOMAN 100ml', 130000, '/images/product_3135.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3136, 'LUCIA  WOMAN 100ml', 130000, '/images/product_3136.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3137, '3\"FULLSPEED\" MAN 100ml', 105000, '/images/product_3137.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3138, 'BLACK AFGANO ', -1, '/images/product_3138.png', 0, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3139, 'SHEIK MAN 100ml', 130000, '/images/product_3139.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3140, 'ACCENT MAN  100ml', 135000, '/images/product_3140.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3141, 'ALLUSIVE CANALE SPORT MAN 80ml', 140000, '/images/product_3141.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3142, 'MAGIE NOIRE  MAN 100ml', 130000, '/images/product_3142.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3143, 'DEUX CENT DUZE MEN  100ml', 130000, '/images/product_3143.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3144, 'SHEIK WOMAN 100ml', 130000, '/images/product_3144.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3145, 'MELODIA WOMAN 90ml', 190000, '/images/product_3145.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3146, '\"VANILLE BOUQUET\" universal 100ml', 150000, '/images/product_3146.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3147, 'SHEIKH AL SHUYUKH CONCENTRATED  MAN', 190000, '/images/product_3147.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3148, 'PARIS NARCOTIQ  MAN 100ml', 130000, '/images/product_3148.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3149, 'AL DUA AL MAKNOON 100ml', 180000, '/images/product_3149.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3150, '8 ELEMENT FOR MEN 100ml', 130000, '/images/product_3150.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3151, ' ZAN Eau de parfum MAN 100ml', 135000, '/images/product_3151.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3152, 'SHEIKH AL SHEIKH MAN 100ml', 130000, '/images/product_3152.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3153, 'TOOMFORD MAN 100ml', 135000, '/images/product_3153.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3154, 'JOURNEY woman 100ml', 160000, '/images/product_3154.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3155, 'LACOSTE EAU DE LACOSTE . original Fransiya', 410000, '/images/product_3155.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3156, 'GUCCI GUILTY   original Fransiya 90ml', 860000, '/images/product_3156.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3157, 'BLUE SEDUCTION FORMEN 100ml original', 290000, '/images/product_3157.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3158, 'clinique happy FOR MEN 100 original', 460000, '/images/product_3158.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3159, 'CHEAPANDCHICH MUSCHINO \"I LOVE\" 100ml original', 460000, '/images/product_3159.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3160, 'BOSS HUGO BOSS BOTTLED 100ml original ', 460000, '/images/product_3160.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3161, 'LANVIN L`HOMME  MAN 100ml original ', 260000, '/images/product_3161.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3162, 'OXYGENE HOMME LANVIN MAN original ', 335000, '/images/product_3162.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3163, 'Si passione  WOMAN 100ml original ', 1310000, '/images/product_3163.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3164, 'VERSACE MAN EAU FRAICHE MAN 100ml  original ', 510000, '/images/product_3164.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3165, 'BVLGARI AQVA POUR HOMME 100ml MAN original ', 660000, '/images/product_3165.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3166, 'LACOSTE POUR HOMME 90ml WOMAN', 410000, '/images/product_3166.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3167, 'DIOR HOMME SPORT 100ml', -1, '/images/product_3167.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3168, 'Mercedes-Benz 120ml MAN original', 460000, '/images/product_3168.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3170, 'Телефонлар', 0, '', 9, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3171, 'REDMI GO', 951900, '/images/product_3171.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 5, 1, 0),
(3172, 'REDMI 7A', 1202400, '/images/product_3172.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3173, 'REDMI 7  32gb', 1472940, '/images/product_3173.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3174, 'REDMI 7   64gb', 1553100, '/images/product_3174.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3176, 'REDMI NOTE 8 64gb', 1903800, '/images/product_3176.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 5, 1, 0),
(3177, 'REDMI NOTE 8 pro 128gb', 2505000, '/images/product_3177.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 5, 1, 0),
(3178, 'REDMI 9s 64gb ', 2204400, '/images/product_3178.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3179, 'REDMI 9s 128gb', 2404800, '/images/product_3179.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3180, 'SAMSUNG  A015', 1352700, '/images/product_3180.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3181, 'SAMSUNG A105', 1492980, '/images/product_3181.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3182, 'SAMSUNG A107', 1563120, '/images/product_3182.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3183, 'SAMSUNG a 205', 1753500, '/images/product_3183.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3184, 'SAMSUNG a207', 1823640, '/images/product_3184.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3185, 'SAMSUNG A307 32gb', 2004000, '/images/product_3185.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3186, 'SAMSUNG A307 64gb', 2154300, '/images/product_3186.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3187, 'SAMSUNG A515 64gb', 2955900, '/images/product_3187.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3188, 'SAMSUNG A515   128gb', 3106200, '/images/product_3188.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3189, 'SAMSUNG S20', 8817600, '/images/product_3189.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3190, 'SAMSUNG s20+', 9569100, '/images/product_3190.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3191, 'SAMSUNG s20 ultra', 13076100, '/images/product_3191.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 3, 1, 0),
(3192, 'REDMI 8  32gb', 1503000, '/images/product_3192.png', 9, 0, 3170, 0, '', 1, NULL, NULL, 0, 1, 0),
(3193, 'Гигиена махсулотлари', 0, '', 8, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3194, '600 14\"Bella Panty Soft deo fresh\" 50+10 шт  ', 22000, '/images/product_3194.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3195, '601 15\"Bella Panty Soft deo fresh\"  20 шт  ', 8500, '/images/product_3195.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3196, '602 16 Bella Herbs Panty  (лечебнье травы) 60 шт', 16000, '/images/product_3196.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3197, '603 17 Bella Herbs Panty  (лечебнье травы) 20 шт', 6000, '/images/product_3197.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3198, '608 18 Традиционнье прокладки \"Bella NOVA\"10 шт', 8500, '/images/product_3198.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3199, '609 19 \"Bella Nova Maxi\"  10 шт', 12000, '/images/product_3199.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3200, '610 20Традиционнье  Bella Nova Deo Fresh 10шт', 8500, '/images/product_3200.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3201, '611 21\"Bella Classic Nova Maxi drainette\" 10 шт', 8500, '/images/product_3201.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3202, '612 22\"Bella Perfecta Night silky drai\" 7 шт', 12500, '/images/product_3202.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3203, '23\"Bella Cotton\" косметические диски 80 шт  ', 8500, '/images/product_3203.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3204, '24\"Bella Cotton\" косметические диски 120 шт  ', 11500, '/images/product_3204.png', 8, 0, 3193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3205, '18/74 Flesh Россия   500мл', 10000, '/images/product_3205.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3235, '497-2 AURA  крем мыло жидкое 500 мл ', 10000, '', 1, 0, 3825, 0, 'Банановое суфле', 1, NULL, NULL, 0, 1, 0),
(3236, '497-3 AURA  крем мыло жидкое 500 мл ', 10000, '', 1, 0, 3825, 0, 'Алое вера и зеленый чай ', 1, NULL, NULL, 0, 1, 0),
(3237, '24/43 Мультяшки', 11000, '/images/product_3237.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3238, '498 Шагам ( шам ) 1 та ', 4000, '/images/product_3238.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3239, ' BLACK AFGANO MAN 100ml', 180000, '/images/product_3239.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3240, 'Набор женский', 260000, '/images/product_3240.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3241, 'Набор женский', 260000, '/images/product_3241.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3242, 'Набор мужской', 330000, '/images/product_3242.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3243, 'Набор мужской', 330000, '/images/product_3243.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3244, 'Набор мужской', 330000, '/images/product_3244.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3245, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3245.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3246, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3246.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3247, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3247.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3248, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3248.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3249, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3249.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3250, '\"Виктория секрет\" спрей для тела', 65000, '/images/product_3250.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3251, '\"Miss Dior\"  WOMAN 25ml', 35000, '/images/product_3251.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3252, '\"CHLOE\" 25ml made in TURKEY', 35000, '/images/product_3252.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3253, '\"Armand basi\"   25ml made in TURKEY', 35000, '/images/product_3253.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3254, '\"ELCAT\"  25ml made in TURKEY', 35000, '/images/product_3254.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3255, '\"Chance\" 25ml', 35000, '/images/product_3255.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3256, '\"L\'imperatrice\" 25ml made in Turkey', 35000, '/images/product_3256.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3257, '\"CHANCE CHANEL\" 25ml made in Turkey', 35000, '/images/product_3257.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3258, '\"SOSPIRO\" man 25ml made in Turkey', 35000, '/images/product_3258.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3259, '\"NARKOTIK\" man 25ml made in Turkey', 35000, '/images/product_3259.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3260, '\"CREED\" man 25ml made in Turkey', 35000, '/images/product_3260.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3261, '\"SMART\" man 25ml made in Turkey', 35000, '/images/product_3261.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3262, '\"LACOSTE\" man 25ml made in Turkey', 35000, '/images/product_3262.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3263, '\"VERSACE\" man 25ml made in Turkey', 35000, '/images/product_3263.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3264, '\"LANVIN\" man 25ml made in Turkey', 35000, '/images/product_3264.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3265, '\"VERSACE\" man 25ml made in Turkey', 35000, '/images/product_3265.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3266, '\"SAUVAGE\" man 25ml made in Turkey', 35000, '/images/product_3266.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3267, '\"020\" man 25ml made in Turkey', 35000, '/images/product_3267.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3268, '\"8 ELEMENT\" man 25ml made in Turkey', 35000, '/images/product_3268.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3269, '\"KIRKE\" man 25ml made in Turkey', 35000, '/images/product_3269.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3270, '\"ELCAT sport\" man 25ml original', 195000, '/images/product_3270.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3271, '\"LUCIA\" woman 25ml made in Turkey', 35000, '/images/product_3271.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3272, '\"LILLYAKAY\" quruq yuzlar uchun upa  original', 88000, '/images/product_3272.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3273, '\"LILLYAKAY\" yogli yuzlar uchun upa  original', 79000, '/images/product_3273.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3274, '\"RUBY\" yogli yuzlar uchun upa  original', 85000, '/images/product_3274.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3275, '\"INKONDESSENCE\" woman original duhi ', 105000, '/images/product_3275.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3276, '\"COLLEGEN \" quruq yuzlar uchun upa  original ', 79000, '/images/product_3276.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3277, '2\"FULLSPED\" Duhi man original', 105000, '/images/product_3277.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3278, '\"LOMANI\" made in dubay man ', 95000, '/images/product_3278.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3279, '1 \"FULLSPED\" Duhi man original ', 105000, '/images/product_3279.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3280, '\"FLUR\" quruq yuzlar uchun upa  original ', 50000, '', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3281, '\"PRARANCE\"  yuzlar uchun upa  original ', 85000, '/images/product_3281.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3282, '\" 05 \" made in dubay', 135000, '/images/product_3282.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3283, '\"ELCAT famme \" woman  original 50ml  oriflame', 195000, '', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3284, '\" LILLIKAY Q10\"  yuzlar uchun upa  original ', 75000, '/images/product_3284.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3285, '\" LILLIKAY \" quruq yuzlar uchun upa  original ', 75000, '/images/product_3285.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3286, '\" ANJO \" quruq  yuzlar uchun upa ', 48000, '/images/product_3286.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3287, '\" MAG \" yog`li  yuzlar uchun upa  original ', 40000, '/images/product_3287.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3288, '\" DINAMIK \"  yuzlar uchun upa  original ', 47000, '/images/product_3288.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3289, '\" FIT we ! \" mativiy pamada stoykiy 24coat', 15000, '', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3290, '\" Hudabeauty \" mativiy pamada stoykiy 24coat', 15000, '/images/product_3290.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3291, '1 \" FIT we ! \" mativiy pamada stoykiy 24coat', 15000, '/images/product_3291.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3292, '2 \" FIT we ! \" mativiy pamada stoykiy 24coat', 15000, '/images/product_3292.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3293, '3 \" FIT we ! \" mativiy pamada stoykiy 24coat', 15000, '/images/product_3293.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3294, '4\" FIT we ! \" mativiy pamada stoykiy 24coat', 15000, '/images/product_3294.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3295, '1\"VIVID MATTE LUQUID\" mat pamada stoykiy 24coat', 13000, '/images/product_3295.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3296, '2\"VIVID MATTE LUQUID\" mat pamada stoykiy 24coat', 13000, '/images/product_3296.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3297, '3\"VIVID MATTE LUQUID\" mat pamada stoykiy 24coat', 13000, '/images/product_3297.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3298, '4\"VIVID MATTE LUQUID\" mat pamada stoykiy 24coat', 13000, '/images/product_3298.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3299, '\"GARNIER\" освежающий витаминный тоник', 48000, '/images/product_3299.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3300, '\"GARNIER\"  мицеллярная вода  400мл', 52000, '/images/product_3300.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3301, '\"L`OREAL\"  мицеллярная вода  ', 65000, '/images/product_3301.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3302, '\"GARNIER\"  молочко для тела  ', 48000, '/images/product_3302.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3303, '\"GARNIER\"  ультра упругость', 48000, '/images/product_3303.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3304, '\"GARNIER\"  мицеллярная вода  ', 48000, '/images/product_3304.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3305, '\"L`OREAL\"  мицеллярная вода  400мл', 65000, '/images/product_3305.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3306, '\"GARNIER\" очищающий гел против чорний точек и ,,,', 52000, '/images/product_3306.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3307, '\"GARNIER\"  мицеллярная вода  ', 48000, '/images/product_3307.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3308, '\"GARNIER\" дневной уход 25+', 49000, '/images/product_3308.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3309, '\"GARNIER\" ботаник крем ', 43000, '/images/product_3309.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3310, '\"GARNIER\" дневний уход  55+', 49000, '/images/product_3310.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3311, '\"L`OREAL PARIS\" Revitalif крем  ', 85000, '/images/product_3311.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3312, '\"L`OREAL\" восстанавливающий уход . дневной ', 85000, '/images/product_3312.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3313, '\"L`OREAL PARIS\" дневной крем    35+ ', 65000, '/images/product_3313.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3314, '\"GARNIER\" уход вокруг глаз 25+', 49000, '/images/product_3314.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3315, '\"GARNIER\" уход вокруг глаз 45+', 49000, '/images/product_3315.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3316, '\"NIVEA\"  мицеллярная вода  ', 53000, '/images/product_3316.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3317, '\"GARNIER\" против прыщей и черных точек', 55000, '/images/product_3317.png', 0, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3318, '\"NIVEA\" дневной крем    45+ ', 50000, '/images/product_3318.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3319, '\"GARNIER\" уход вокруг глаз 35+', 49000, '/images/product_3319.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3320, '\"GARNIER\" Защита от морщин . Ночной уход 35+', 49000, '/images/product_3320.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3321, '\"GARNIER\" Защита от морщин . Дневний уход 35+', 49000, '/images/product_3321.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3322, '11/32- Ок урик 1 кг ', -9000, '/images/product_3322.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3323, '13/28 Чипсы \"CHEERS\" 220гр', 14000, '/images/product_3323.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3324, '11/33 Ок урик  0.5кг ', -4500, '/images/product_3324.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3325, 'Розетки и выключатели', 0, '', 9, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3326, '\"VESTA\" выключатель 1 наружный ', 10300, '/images/product_3326.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3327, '\"VESTA\" выключатели 1 внутренний', 9700, '/images/product_3327.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3328, '\"VESTA\" выключатель 3 внутренний', 18400, '/images/product_3328.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3329, '\"VESTA\" выключатель 2 наружный ', 10300, '/images/product_3329.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3330, '\"VESTA\" Розетки 1 наружный ', 9700, '/images/product_3330.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3331, '\"VESTA\" Розетки 1 внутренний', 10300, '/images/product_3331.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3332, '\"VESTA\" выключатель 2 внутренний', 11600, '/images/product_3332.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3333, '\"VESTA\" Розетки 2 наружный ', 11000, '/images/product_3333.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3334, '\"VESTA\" Розетки 2 внутренний ', 13800, '/images/product_3334.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3335, '\"VESTA \"Розетка телевизионная ', 20400, '/images/product_3335.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3336, '\"VIKO\" Розетка телефона одинарная', 20600, '/images/product_3336.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3337, '\"VIKO\" Розетка  для TV антенны', 24000, '/images/product_3337.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3338, '\"VIKO\" Розетка одинарная без заземления', 19800, '/images/product_3338.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3339, '\"VIKO\" Выключатель двойной', 21600, '/images/product_3339.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3340, '\"VIKO\" Выключатель трехклавишный', 32400, '/images/product_3340.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3341, '\"VIKO\" Выключатель одинарный', 19800, '/images/product_3341.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3342, '\"VIKO\" Рамка 5-ая meridian', 24000, '/images/product_3342.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3343, '\"VIKO\" Рамка 4-ая meridian', 18000, '/images/product_3343.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3344, '\"VIKO\" Рамка 3-ая meridian', 14400, '/images/product_3344.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3345, '\"VIKO\" Рамка 2-ая meridian', 10800, '/images/product_3345.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3346, 'Лампочки', 0, '', 9, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3347, '\"AKFA LED lighting\" 12w', 20000, '/images/product_3347.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3348, '\"AKFA LED lighting\" 10w', 17700, '/images/product_3348.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3349, '\"AKFA LED lighting\" 7w', 15300, '/images/product_3349.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3350, '\"AKFA LED lighting\" 5w', 14000, '/images/product_3350.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3351, '\"AKFA LED lighting\" 18w', 37400, '/images/product_3351.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3352, '\"AKFA LED lighting\" 30w', 51300, '/images/product_3352.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3353, '\"AKFA LED lighting\" 16w', 30300, '/images/product_3353.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3354, '\"AKFA LED lighting\" 40w', 58600, '/images/product_3354.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3355, '\"AKFA LED lighting\" 30w', 49200, '/images/product_3355.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3356, '\"AKFA LED lighting\" 60w', 101200, '/images/product_3356.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3357, '\"AKFA LED lighting\" 20w', 35100, '/images/product_3357.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3358, '\"AKFA LED lighting\" 45w', 70200, '/images/product_3358.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3359, '\"AKFA LED lighting\" 9w внутренний круглый', 30100, '/images/product_3359.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3360, '\"AKFA LED lighting\" 9w внутренний квадрат', 31400, '/images/product_3360.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3361, '\"AKFA LED lighting\" 6w внутренний круглый', 23400, '/images/product_3361.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3362, '\"AKFA LED lighting\" 6w внутренний квадрат', 24400, '', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3363, '\"AKFA LED lighting\" 4w внутренний круглый', 20700, '/images/product_3363.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3364, '\"AKFA LED lighting\" 4w внутренний квадрат', 22000, '/images/product_3364.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3365, '\"AKFA LED lighting\" 3w внутренний круглый', 17200, '/images/product_3365.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3366, '\"AKFA LED lighting\" 3w внутренний квадрат', 18600, '/images/product_3366.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3367, '\"AKFA LED lighting\" 12w внутренний круглый', 35700, '/images/product_3367.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3368, '\"AKFA LED lighting\" 12w внутренний квадрат', 36700, '/images/product_3368.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3369, '\"AKFA LED lighting\" 15w внутренний круглый', 45300, '/images/product_3369.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3370, '\"AKFA LED lighting\" 15w внутренний квадрат', 46500, '/images/product_3370.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3371, '\"AKFA LED lighting\" 18w внутренний круглый', 48500, '/images/product_3371.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3372, '\"AKFA LED lighting\" 18w внутренний квадрат', 51000, '/images/product_3372.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3373, '\"AKFA LED lighting\" 24w внутренний круглый', 82900, '/images/product_3373.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3374, '\"AKFA LED lighting\" 24w внутренний квадрат', 85600, '/images/product_3374.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3375, '\"AKFA LED lighting\" 10w ', 23500, '/images/product_3375.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3376, '\"AKFA LED lighting\" 20w ', 41500, '/images/product_3376.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3377, '\"AKFA LED lighting\" 20w', 50400, '/images/product_3377.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3378, '\"AKFA LED lighting\" 5w ', 19300, '/images/product_3378.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3379, '\"AKFA LED lighting\" 12w наружный  круглый', 42700, '/images/product_3379.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3380, '\"AKFA LED lighting\" 12w наружный квадрат', 44600, '/images/product_3380.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3381, '\"AKFA LED lighting\" 18w наружный  круглый', 59400, '/images/product_3381.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3382, '\"AKFA LED lighting\" 18w наружный квадрат', 60000, '/images/product_3382.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3383, '\"AKFA LED lighting\" 24w наружный  круглый', 82900, '/images/product_3383.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3384, '\"AKFA LED lighting\" 24w наружный квадрат', 84200, '/images/product_3384.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3385, 'Коробки для электромонтаж', 1500, '/images/product_3385.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3386, 'Коробки для электромонтаж', 1500, '/images/product_3386.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3387, 'Коробки для электромонтаж 12x12', 3600, '/images/product_3387.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3388, 'Коробки для электромонтаж  10x10', 3600, '/images/product_3388.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3389, '\"LED SHINE\" Светодиодная лента (1метр) зеленый', 4500, '/images/product_3389.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3390, '\"LED SHINE\" Светодиодная лента (1метр) синий', 6000, '/images/product_3390.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3391, '\"LED SHINE\" Светодиодная лента (1метр) красный', 6000, '/images/product_3391.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 1, 1, 0),
(3392, '\"LED SHINE\" Светодиодная лента (1метр) Жёлтый', 6000, '/images/product_3392.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3393, '\"KLAUS\" led lamba e27 5watt', 10200, '/images/product_3393.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3394, '\"KLAUS\" led lamba e27 5watt mini', 9000, '/images/product_3394.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3395, '\"KLAUS\" led lamba e27 7watt', 11400, '/images/product_3395.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3396, '\"KLAUS\" led lamba e27 9watt', 12240, '/images/product_3396.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3397, '\"KLAUS\" led lamba e27 12watt', 13800, '/images/product_3397.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3398, '\"KLAUS\" led lamba e27 15watt', 16800, '/images/product_3398.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3399, '\"KLAUS\" led lamba e27 20watt', 28800, '/images/product_3399.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3400, '\"KLAUS\" led lamba e27 30watt', 39600, '/images/product_3400.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3401, '\"KLAUS\" led lamba e27 40watt', 62400, '/images/product_3401.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3402, '\"KLAUS\" led lamba e27 50watt', 69600, '/images/product_3402.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3403, '\"KLAUS\" led lamba e14 6watt', 12600, '/images/product_3403.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3404, '\"KLAUS\" EXHAUST FAN 100mm 15watt', 84000, '/images/product_3404.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3405, '\"KLAUS\" EXHAUST FAN 125mm 20watt', 96000, '/images/product_3405.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3406, '\"KLAUS\" EXHAUST FAN 150mm 25watt', 108000, '/images/product_3406.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3407, '\"GIP\" EXHAUST FAN 100mm ', 72000, '/images/product_3407.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3408, '\"GIP\" EXHAUST FAN 125mm ', 98400, '/images/product_3408.png', 9, 0, 3325, 0, '', 1, NULL, NULL, 0, 1, 0),
(3409, '\"СТАЛКЕР\" 3w внутренний круглый', 10200, '/images/product_3409.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3410, '\"СТАЛКЕР\" 3w внутренний квадрат', 12000, '/images/product_3410.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3411, '\"СТАЛКЕР\" 4w внутренний круглый', 14400, '/images/product_3411.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3412, '\"СТАЛКЕР\" 4w внутренний квадрат', 14400, '/images/product_3412.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3413, '\"СТАЛКЕР\" 6w внутренний круглый', 15600, '/images/product_3413.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3414, '\"СТАЛКЕР\" 6w внутренний квадрат', 15600, '/images/product_3414.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3415, '\"СТАЛКЕР\" 9w внутренний круглый', 18000, '/images/product_3415.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3416, '\"СТАЛКЕР\" 9w внутренний квадрат', 20400, '/images/product_3416.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3417, '\"СТАЛКЕР\" 12w внутренний круглый', 21600, '/images/product_3417.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3418, '\"СТАЛКЕР\" 12w внутренний квадрат', 24000, '', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3419, '\"СТАЛКЕР\" 15w внутренний круглый', 27600, '/images/product_3419.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3420, '\"СТАЛКЕР\" 15w внутренний квадрат', 27600, '/images/product_3420.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3421, '\"СТАЛКЕР\" 18w внутренний круглый', 43200, '/images/product_3421.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3422, '\"СТАЛКЕР\" 18w внутренний квадрат', 43200, '', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3423, '\"СТАЛКЕР\" 24w внутренний квадрат', 50400, '/images/product_3423.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3424, '\"СТАЛКЕР\" 24w внутренний квадрат', 54000, '', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3425, '\"СТАЛКЕР\" 6w наружный  круглый', 19800, '/images/product_3425.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3426, '\"СТАЛКЕР\" 6w наружный  квадрат', 21600, '/images/product_3426.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3427, '\"СТАЛКЕР\" 12w наружный  круглый', 24000, '/images/product_3427.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3428, '\"СТАЛКЕР\" 12w наружный  квадрат', 26400, '/images/product_3428.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3429, '\"СТАЛКЕР\" 24w наружный  круглый', 52800, '/images/product_3429.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3430, '\"СТАЛКЕР\" 24w наружный  квадрат', 54000, '/images/product_3430.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3431, '\"СТАЛКЕР\" 18w наружный  круглый', 34800, '/images/product_3431.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3432, '\"СТАЛКЕР\" 18w наружный  квадрат', 36000, '/images/product_3432.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3434, 'трубка светодиодная', 29500, '/images/product_3434.png', 0, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3435, '\"AKFA LED lighting\" 18w трубка светодиодная', 29500, '/images/product_3435.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3436, '\"AKFA LED lighting\" 10w трубка светодиодная', 29700, '/images/product_3436.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3437, '\"AKFA LED lighting\" 20w трубка светодиодная', 35000, '/images/product_3437.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3438, '\"AKFA LED lighting\" 30w трубка светодиодная', 49800, '/images/product_3438.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3439, '\"AKFA LED lighting\" 40w трубка светодиодная', 58800, '/images/product_3439.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3440, '\"AKFA LED lighting\" 30w трубка светодиодная', 59800, '/images/product_3440.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3441, '\"AKFA LED lighting\" 40w трубка светодиодная', 68000, '/images/product_3441.png', 9, 0, 3346, 0, '', 1, NULL, NULL, 0, 1, 0),
(3442, '24/44 Mультяшки 1 дона', 2000, '/images/product_3442.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3443, '\"NIVEA\"  мицеллярная вода  ', 53000, '/images/product_3443.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3444, '\"NIVEA\" Защита от морщин .ТОНИК ', 50000, '/images/product_3444.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3445, '\"NIVEA\" крем для лича . ночной', 43000, '/images/product_3445.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3446, '\"NIVEA\" SOFT  (интенсивный увлажняющий крем)', 34000, '/images/product_3446.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3447, '\"faberlic\" NIGHT PHYTO CRAEM 30+', 49000, '/images/product_3447.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3448, '\"faberlic\" EYE PHYTO CRAEM 30+', 49000, '/images/product_3448.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3449, '\"faberlic\" DAY PHYTO CRAEM 30+', 49000, '/images/product_3449.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3450, '\"NIVEA\" CARE крем для лица увлажняюший', 43000, '/images/product_3450.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3451, '\"Charcoal\" Черная маска-пленка для чистки пор', 35000, '/images/product_3451.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3452, '7/34 Желатин пищевой  10 гр ', 1000, '/images/product_3452.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(3453, '\"DR-RASHEL\" маска с коллагеном и золотом', 35000, '/images/product_3453.png', 8, 0, 3119, 0, 'Пленочная маска с коллагеном и золотом деликатно очищает верхний слой кожи, делает ее мягкой и нежной, способствует обогащению кислородом и микроэлементами.', 1, NULL, NULL, 0, 1, 0),
(3454, '\"GARNIER\" Уход-крем для рук 100мл', 43000, '/images/product_3454.png', 8, 0, 3119, 0, ' Интенсивный для очень сухой кожи ', 1, NULL, NULL, 0, 1, 0),
(3455, '\"VERSUS\" дезодорант', 35000, '/images/product_3455.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3456, '\"Evidence\" дезодорант', 35000, '/images/product_3456.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3457, 'Бальзам для губ Смайлы 1 шт', 10000, '/images/product_3457.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3458, '\"Pink Dress\" дезодорант', 35000, '/images/product_3458.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3459, '\"DIVINE\" дезодорант', 35000, '/images/product_3459.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3460, '\"GLAMOUR\" дезодорант', 35000, '/images/product_3460.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3461, '\"Clear\" Шампунь против перхоти для женщин ', 38000, '/images/product_3461.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3462, '\"Pantene\" Шампуни в Махачкале ', 42000, '/images/product_3462.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3463, '4\"Head & Shoulders\" шампунь против перхоти ', 45000, '/images/product_3463.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3464, '3\"Head & Shoulders\" шампунь против перхоти ', 45000, '/images/product_3464.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3465, '2\"Head & Shoulders\" шампунь против перхоти ', 45000, '/images/product_3465.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3466, '1\"Head & Shoulders\" шампунь против перхоти MEN', 45000, '/images/product_3466.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3467, '\"NIVEA\" гел-уход для душа (апелсин)', 35000, '/images/product_3467.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3468, '\"NIVEA\" гел-уход для душа (питание и зобота)', 35000, '/images/product_3468.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3469, '\"NIVEA\" гел-уход для душа (жемчужины масел)', 35000, '/images/product_3469.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3470, '1\"NIVEA\" средство для снятия макияжа с глаз', 42000, '/images/product_3470.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3471, '2\"NIVEA\" средство для снятия макияжа с глаз', 42000, '/images/product_3471.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3472, '\"FARSALI\"  Skintune Blur Perfecting Primer Serum', 28000, '/images/product_3472.png', 8, 0, 3119, 0, 'Гибридный праймер-сыворотка, которая мягко размывает кожу, уменьшает появление пор и дефектов, и создает осветленный, тонко настроенный эффект', 1, NULL, NULL, 0, 1, 0),
(3473, '\"FARSALI\"  24K GOLD ELIXIR', 28000, '/images/product_3473.png', 8, 0, 3119, 0, 'Гибридный праймер-сыворотка, которая мягко размывает кожу, уменьшает появление пор и дефектов, и создает осветленный, тонко настроенный эффект', 1, NULL, NULL, 0, 1, 0),
(3474, '\"Farsali\" Rose Gold Elixir', 28000, '/images/product_3474.png', 8, 0, 3119, 0, 'Гибридный праймер-сыворотка, которая мягко размывает кожу, уменьшает появление пор и дефектов, и создает осветленный, тонко настроенный эффект', 1, NULL, NULL, 0, 1, 0),
(3475, '\"ICONIK\"   Хайлайтер ', 40000, '/images/product_3475.png', 8, 0, 3119, 0, 'Хайлайтер для лица представляет собой восхитительное средство, которое выделит вас и подчеркнет вашу индивидуальность.', 1, NULL, NULL, 0, 1, 0),
(3476, 'Huda Beauty    Хайлайтер', 35000, '/images/product_3476.png', 8, 0, 3119, 0, 'Хайлайтер для лица представляет собой восхитительное средство, которое выделит вас и подчеркнет вашу индивидуальность.', 1, NULL, NULL, 0, 1, 0),
(3477, 'CROME BB  SNAIL B.B CREAM ', 50000, '/images/product_3477.png', 8, 0, 3119, 0, 'Многофункциональный ББ-крем Magic Snail BB Cream от корейского бренда Bergamo позволит создавать безупречный макияж.', 1, NULL, NULL, 0, 1, 0),
(3478, '\"GARNIER\" Уход-крем для ног 100мл', 43000, '/images/product_3478.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3479, '\"NIVEA\"Крем для лица Q10 50мл  увлажняющий ', 50000, '/images/product_3479.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3480, '\"NIVEA\" Увлажняющий крем универсальный, 30 мл', 30000, '/images/product_3480.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3481, '\"FARSALI\" Сыворотка 4шт', 52000, '/images/product_3481.png', 8, 0, 3119, 0, 'Концентрированное средство для мгновенного, глубокого и длительного увлажнения кожи. ', 1, NULL, NULL, 0, 1, 0),
(3482, '\"BLACK SNAL\" Таналка', 65000, '/images/product_3482.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3483, '\"FARSALI\"  Сыворотка для лица в Хмельницком', 28000, '/images/product_3483.png', 8, 0, 3119, 0, 'Гибридный праймер-сыворотка, которая мягко размывает кожу, уменьшает появление пор и дефектов, и создает осветленный, тонко настроенный эффект', 1, NULL, NULL, 0, 1, 0),
(3484, '\"Dear She\" Пузырьковая маска для лица ', 50000, '/images/product_3484.png', 8, 0, 3119, 0, 'BioAqua Очищающая кислородная пузырьковая маска для лица на основе глины', 1, NULL, NULL, 0, 1, 0),
(3485, '\"КРАСНАЯ ЛИНИЯ\" интимная Нежный гель 250г', 35000, '/images/product_3485.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3486, '\"КРАСНАЯ ЛИНИЯ\" Жидкое мыло для интимной гигиены', 35000, '/images/product_3486.png', 8, 0, 3119, 0, 'маслом австралийского чайного дерева ТМ Красная линия', 1, NULL, NULL, 0, 1, 0),
(3487, '\"faberlic\" storie d`amore  интимная Нежный гель ', 45000, '/images/product_3487.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3488, '\"Catrice HD Liquid Coverage\" Тональный крем 30 мл', 38000, '/images/product_3488.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3489, '\"LillyKay\" Gold Essence крем для лица  50мл', 45000, '/images/product_3489.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3490, 'Super Stay 24Н тональный крем maybelline ', 69000, '/images/product_3490.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3491, '\"EMELIE paris\" тональный крем ', 45000, '/images/product_3491.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3492, '\"MAYBELLINE\" dream santin fluid тональный крем', 69000, '/images/product_3492.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3493, '\"ideal FACE\" тональный крем', 75000, '/images/product_3493.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0);
INSERT INTO `products` (`id`, `name`, `price`, `image`, `partner_id`, `group`, `parent_id`, `type`, `comments`, `active`, `date_created`, `options`, `rating`, `status`, `discount`) VALUES
(3494, '\"LillyKay\"  BB крем ', 65000, '/images/product_3494.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3495, '\"PRORANCE\" BAZA', 75000, '/images/product_3495.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3496, '\"COLLAGEN\" тональный крем', 48000, '/images/product_3496.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3497, '\"MISSHA\" тональный крем  ', 60000, '/images/product_3497.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3498, '\"ICONIK\"  london   Хайлайтер ', 45000, '/images/product_3498.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3499, '\"feberlic\"   Крем для рук  увлажняющий ', 15000, '/images/product_3499.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3500, '\"ВЕСНА\" НЕЖНЫЙ   Крем для рук  увлажняющий ', 13500, '/images/product_3500.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3501, '\"Бархатные ручки\" Крем для рук  увлажняющий ', 15000, '/images/product_3501.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3502, '\"Бархатные ручки\" НУЖНОСТЬ ТИАРЕ Крем для рук', 15000, '/images/product_3502.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3503, '\"Кк Kosmetika\"  Крем питательный', 15000, '/images/product_3503.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3504, '\"ICONIK\"  london prep.set.glow   Хайлайтер ', 45000, '/images/product_3504.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3505, '\"EVELINE\" EXTRA SOFT крем', 33000, '/images/product_3505.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3506, '\"GLADE\" освежитель воздуха', 80000, '/images/product_3506.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3507, '\"NIVEA\" бальзам после бритья', 65000, '/images/product_3507.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3508, '\"faberlic\" гель для душ', 45000, '/images/product_3508.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3509, '\"faberlic\" BOTANICA  мицеллярная вода  ', 50000, '/images/product_3509.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3510, 'аппарат для депиляции', 75000, '/images/product_3510.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3511, '1 .шугаринг для депиляции', 35000, '/images/product_3511.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3512, '2 .шугаринг для депиляции', 45000, '/images/product_3512.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3513, '3 .шугаринг для депиляции', 35000, '/images/product_3513.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3514, '\"Pro Wax 100\" Воскоплав баночный ', 160000, '/images/product_3514.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3515, '\"Gold Hydrogel\"  Маска для кожи вокруг глаз ', 45000, '/images/product_3515.png', 8, 0, 3119, 0, 'ShangPree Гидрогелевые патчи под глаза с Золотом ', 1, NULL, NULL, 0, 1, 0),
(3516, '\"NIVEA\" пена для бритья', 54000, '/images/product_3516.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3517, '\"MAYBELLINE\"  консилер', 43000, '/images/product_3517.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3518, '\"NUDE\" 3x1 (тушь&подводка&карандаш)', 32000, '/images/product_3518.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3519, '\"AVON\" ULtrA VOLUME  тушь', 45000, '/images/product_3519.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3520, '\"KARITE\" подводка', 17000, '/images/product_3520.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3521, 'BIG LASH  тушь', 45000, '/images/product_3521.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3522, '\"MAYBILLINE\" BIG SHOT  тушь', 65000, '/images/product_3522.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3523, '\"MAYBILLINE\" LASH SENSATIONAL  тушь', 65000, '/images/product_3523.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3524, 'LENGTR UP     тушь', 45000, '/images/product_3524.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3525, 'SIGNIFICANT  тушь', 65000, '/images/product_3525.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3526, '\"NIVEA MEN\" ULTRA шампунь-уход ', 35000, '/images/product_3526.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3527, '\"NIVEA MEN\" СИЛА УГЛЯ шампунь-уход ', 35000, '', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3528, '\"NIVEA\" МОЛОЧКОДЛЯ ВОЛОС шампунь-уход ', 35000, '/images/product_3528.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3529, '\"NIVEA\" СИЯНИЕ И ЗАБОТА шампунь-уход ', 35000, '/images/product_3529.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3530, '\"NIVEA MEN\" Освежающий шампунь-гел 3/1', 35000, '/images/product_3530.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3531, '\"GLADE\" освежитель воздуха (японский сад)', 25000, '/images/product_3531.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3532, '\"GLADE\" освежитель воздуха (морской)', 25000, '/images/product_3532.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3533, '\"AIR WICK\" до 60 дней свежести (дикий гранат)', 45000, '/images/product_3533.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3534, '\"AIR WICK\" PURE (пачули и евкалипта)', 45000, '/images/product_3534.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3535, '\"AIR WICK\" до 60 дней свежести (лимон и женьшень)', 45000, '/images/product_3535.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3536, '\"AIR WICK\" life scents (многослойный аромат)', 45000, '/images/product_3536.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3537, '\"AIR WICK\" PURE (солнечный цитрус)', 45000, '/images/product_3537.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3538, '\"AIR WICK\"   (сладкая ваниль)', 45000, '/images/product_3538.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3539, '\"NIVEA MEN\" Заряд свежести 48ч ', 25000, '/images/product_3539.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3540, '\"AIR WICK\" PURE (цветущая вишня)', 45000, '/images/product_3540.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3541, '\"AIR WICK\" PURE (голубая лагуна)', 45000, '/images/product_3541.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3542, '\"AIR WICK\" магнолия и цветущая вишня', 43000, '/images/product_3542.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3543, '\"GLADE\" освежитель воздуха (Индонезийский сандал)', 25000, '/images/product_3543.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3544, '\"lady speed stick\" 24/7 (дыхание ш свежесть)', 25000, '/images/product_3544.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3545, '\"lady speed stick\" 24/7 (свежесть облоков)', 25000, '/images/product_3545.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3546, '\"Rexona men\" motionsense antibacterial', 24000, '/images/product_3546.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3547, '\"Rexona men\" motionsense antibacterial 48ч', 24000, '/images/product_3547.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3548, '\"Mennen speed stick\"  энергия стихий', 30000, '/images/product_3548.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3549, '\"AVON\" INDUVIDUAL BLUE ', 25000, '/images/product_3549.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3550, '\"Old Spice\" SITRON ', 35000, '/images/product_3550.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3551, '\"Old Spice\" WOLFTHORN sprey', 35000, '/images/product_3551.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3552, '\"Old Spice\" Wolfthorn Дезодорант стик ', 35000, '/images/product_3552.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3553, '\"GARNIER\" MEN mineral', 25000, '/images/product_3553.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3554, '\"GARNIER\" mineral невидимый ледяная свежесть', 25000, '/images/product_3554.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3555, '\"MENNEN Speed stick\" 24/7 невидимый защита', 25000, '/images/product_3555.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3556, '\"AVON\" little black dress', 25000, '/images/product_3556.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3557, '\"lady speed stick\" fresh & essence juicy magic', 25000, '/images/product_3557.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3558, '\"REXONA\" MEN  COBALT DRY', 25000, '/images/product_3558.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3559, '\"DEONICA\" FOR MEN активная защита', 25000, '/images/product_3559.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3560, '\"DEONICA\"  про защита', 25000, '/images/product_3560.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3561, '\"Emotion\" love', 23000, '/images/product_3561.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3562, '\"Taft\" Гель-воск для укладки волос  Три погоды ', 43000, '/images/product_3562.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3563, '\"johnson\'s baby\" Детское масло  200мл', 43000, '/images/product_3563.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3564, '\"johnson\'s baby\" Детское Шампунь 300мл', 32000, '/images/product_3564.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3565, '\"johnson\'s \" Детское Шампунь 300мл', 32000, '/images/product_3565.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3566, '\"HUDABEAUTY\" подводка', 20000, '/images/product_3566.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3567, '\"WATER PROOF\" подводка', 20000, '/images/product_3567.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3568, '\"JACLIM HILL\" подводка', 23000, '/images/product_3568.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3569, '\"HUDABEAUTY\" подводка 302 ', 20000, '/images/product_3569.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3570, '\"REXONA\" antibacterial protection', 24000, '/images/product_3570.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3571, 'Ресницы', 20000, '/images/product_3571.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3572, '\"BLUSH\" румяна', 27000, '/images/product_3572.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3573, '\"Angel Mask \"тени для глаз', 34000, '/images/product_3573.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3574, '\"NOTE\" 5D Ресницы ', 20000, '/images/product_3574.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3575, '\"NOTE\" 6D Ресницы ', 20000, '/images/product_3575.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3576, '\"EYE FOCUS\" тень', 23000, '/images/product_3576.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3577, '\"ARtist\" тень', 45000, '/images/product_3577.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3578, '\"15 face palette\" тень', 45000, '/images/product_3578.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3579, '\"EVER BEAUTY\" Beauty killer  тень', 42000, '/images/product_3579.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3581, '\"REVOLUTION\" Sophx     тень', 45000, '/images/product_3581.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3582, '\"BLUSH 5\"   Хайлайтер ', 45000, '/images/product_3582.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3583, '\"BROWSPALETTE\" тени для бровей', 35000, '/images/product_3583.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3584, '\"QIAOYAN\" тень', 45000, '/images/product_3584.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3585, '\"EYESHADOW\"  тень', 85000, '/images/product_3585.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3586, '\"DoDo Girl \" Eyeshadow PALETTE тень', 65000, '/images/product_3586.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3587, '\"HUDABEAUTY\"    тень', 65000, '/images/product_3587.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3588, '\"terteist pro\"  тень', 55000, '/images/product_3588.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3589, '\"EVER BEAUTY\" тень', 23000, '/images/product_3589.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3590, '\"BROWS\"     тень', 35000, '/images/product_3590.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3591, '\"NUDE\"     тень', 30000, '/images/product_3591.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3592, 'ногти ', 13000, '/images/product_3592.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3593, '\"HUDABEAUTY\"    тень', 42000, '/images/product_3593.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3594, '\"ANNA ROSE\"    тень', 24000, '/images/product_3594.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3595, '\"HUDABEAUTY\" GLOW     Хайлайтер ', 45000, '/images/product_3595.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3596, '\"MISS ROSE\"   Хайлайтер ', 28000, '/images/product_3596.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3597, '\"MSYAHO\" BAKING SUNSHINE   Хайлайтер ', 32000, '/images/product_3597.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3598, '\"Nuobeier\" румяна', 20000, '/images/product_3598.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3599, '\"HUDABEAUTY\" румяна', 20000, '/images/product_3599.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3600, '\"Delia\" краска для бровей', 33000, '/images/product_3600.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3601, '\"JACLIM HILL\" Консилер', 20000, '/images/product_3601.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3602, '\"HUDABEAUTY\" подводка ', 17000, '/images/product_3602.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3603, '\"Johnson’s Baby \" Шампунь \"Блестящие локоны\"', 32000, '/images/product_3603.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3604, 'AvonSensesШампунь-гель для душа для мужчин ', 30000, '/images/product_3604.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3605, '\"PANTENE\" Бальзам для волос  3Minute Miracle ', 40000, '/images/product_3605.png', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3606, '\"GARNIER\" освежающий тоник', 48000, '', 8, 0, 3119, 0, '', 1, NULL, NULL, 0, 1, 0),
(3607, '11/34 Хандалак 1 дона ', -8500, '/images/product_3607.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3609, '11/35 Шакар олма 1 кг ', -10000, '/images/product_3609.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3610, '13/29 Семeчки \"ERMAK\" 160 ГР', 8000, '/images/product_3610.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3611, '499 Губка магис 5 шт ', 7000, '/images/product_3611.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3612, '500 AZELIT Анти жир для Казан ', 23000, '/images/product_3612.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3613, '10-38 \"RIGA GOLD\" сардины  в масле', 17000, '/images/product_3613.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(3614, '423-Persil color GEL 780 мл ', 38500, '/images/product_3614.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3615, '501 CIf крем 500 мл ', -22000, '/images/product_3615.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3616, '19/Музкаймоклар', 0, '/images/product_3616_1602625937.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3617, '423 Persil color GEL 1,3 лт ', 60000, '/images/product_3617.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3618, '4/86 Сыр Мазорелла  1 кг ', -58000, '/images/product_3618.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(3619, '502 Дихлафос 250 мл', 15000, '/images/product_3619.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3620, '503 Super BAT спирали от камаров 15 та ', 7000, '/images/product_3620.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3621, '504 Пластины от камаров 10шт', 3000, '/images/product_3621.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3622, '505 От камаров 60ночей + фумигатор ', 21000, '/images/product_3622.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3623, '506 Комплект от комаров 45 ночей ', 21000, '/images/product_3623.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3624, '507 Комплект от камаров 70 ночей ', 24000, '/images/product_3624.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3625, '508 Комарофф Гель от камаров 45 мл', 7000, '/images/product_3625.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3626, '509 Комарофф КРЕМ от комаров 60 мл', 7000, '/images/product_3626.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3627, '424 Миф автомат 9 кг ', 0, '/images/product_3627.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3628, '13/30 Семечки \"Мастер жарки\" 20 гр', -500, '/images/product_3628.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3641, '19/12 Музкаймок Бочка DAZA ', 1000, '/images/product_3641.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3642, '7/35- Крахмал кукурузный 50 гр ', 2500, '/images/product_3642.png', 1, 0, 1199, 0, '', 1, NULL, NULL, 0, 1, 0),
(3643, '510 Перчатки для уборки', 10000, '/images/product_3643_1602760834.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3644, '4/87 Сузма 1 кг', -13000, '/images/product_3644_1602841063.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(3645, '4/88 Сузма 0,5 кг', -6500, '/images/product_3645_1602841082.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(3647, '18/75 PULS Energy Drink Original', 7000, '/images/product_3647.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3648, '18/76 PULS Energy Drink Berries', 7000, '/images/product_3648.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3650, '18/77 PULS Energy Drink Exotic', 7000, '/images/product_3650.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3651, '18/78 Dena Zavrik груша яблоко', 2500, '/images/product_3651.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3652, '511 Lenor 1л детский', 25000, '/images/product_3652.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3653, '2/42 Salari екстра варёная 1кг', -45000, '/images/product_3653_1614685912.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3654, '2/43 Salari докторская  1кг', 38000, '/images/product_3654_1614687178.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3656, '1/35- Помидор \" Черри \" 1 кг ', -65000, '/images/product_3656.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3657, '1/35-Помидор \" Черри \" 500гр ', -32500, '/images/product_3657.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3658, '19/13 Музкаймок EXOTIC 85 гр', -3000, '/images/product_3658_1602859973.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3659, '4/89 Каймок 1л', -33000, '/images/product_3659_1602840999.png', 1, 0, 1194, 0, '', 1, NULL, NULL, 0, 1, 0),
(3660, '1/36- Петрушка 1 бог ', -1500, '/images/product_3660.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3671, '14/26 Медовик 1 дона ', 8000, '', 1, 0, 1768, 0, '', 1, NULL, NULL, 0, 1, 0),
(3672, '1/37- Ялпиз 1дона ', -2000, '/images/product_3672.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3673, '11/36- Ковун шакарпалак 1та ', -11000, '', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3674, '512 Бреф делюкс цветок 50 гр', 16000, '/images/product_3674_1602760936.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3675, '512-Бреф делюкс цветок 2х50 гр ', 27000, '/images/product_3675.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3676, '513 Жидкость от камаров 70 ночей  45мл ', 12500, '/images/product_3676.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3677, '514 Жидкость от камаров 45 ноч 30 мл ', 11000, '', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3678, '24/45 Падгузники Онлем 3 /48', 70000, '/images/product_3678.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3679, '19/14 Музкаймок Московиский эскимо ВАЗИРА 90 гр', 3000, '/images/product_3679_1602859902.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3680, '19/15 Музкаймок российский зарли ВАЗИРА 70 гр ', -2500, '/images/product_3680_1602859955.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3681, '19-16  Музкаймок Избушка ВАЗИРА 215+5 гр ', 6000, '/images/product_3681_1602859876.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3682, '19/17 Музкаймок Простаквашино ВАЗИРА 215+5 гр ', 5000, '/images/product_3682_1602859848.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3683, '19/18 Музкаймок Panki ВАЗИРА 80+5 гр ', 4000, '/images/product_3683_1602859826.png', 1, 0, 3616, 0, '', 1, NULL, NULL, 0, 1, 0),
(3684, ' Fanta sitrus 1 лт ', 7000, '/images/product_3684.png', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(3685, '18/79 Sayhun 10 лт ', 12000, '/images/product_3685_1610781724.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3686, '18/80 Sayhun 5 лт ', 7000, '/images/product_3686_1610781784.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3687, '12/54 OREO печеные шоколадный 95 гр', 8000, '/images/product_3687.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3688, '18/81 Fanta sitrus 1 лт', 8000, '/images/product_3688_1610781916.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3689, '18/82 Fanta sitrus 0,5 лт', 6000, '/images/product_3689_1610781955.png', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3691, '18/83 \"Jivy\" 450 мл apelsin', 5000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3692, '18/84\"Jivy\" 450 мл anor', 5000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3693, '18/85\"Jivy\" 450 мл limon', 5000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3694, '18/86\"Jivy\" 450 мл limon', 5000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3695, '18/87\"Jivy\" 450 мл tarvuz', 5000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3696, '18/88\"Jivy\" 850 мл  laym', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3697, '18/89\"Jivy\" 850 мл  limon', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3698, '18/90\"Jivy\" 850 мл apelsin', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3699, '18/91\"Jivy\" 850 мл ananas', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3700, '18/92\"Jivy\" 850 мл  anor', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3701, '18/93\"Jivy\" 850 мл  tarvuz', 7000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3702, '12/55 Кonla kream 1кг', 20000, '/images/product_3702_1602759898.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3703, '12/56 konla kream 0,5кг', 10000, '/images/product_3703_1602759928.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3712, '12/57 \"OLE\"  1кг', 40000, '/images/product_3712_1602760380.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3713, '12/58 \"OLE\"  0,5кг', 20000, '/images/product_3713_1602760407.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3714, '12/59 \"OLE\"  1шт', 1000, '/images/product_3714_1602760430.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3715, '12/60 \"PANKI\" 1кг', 50000, '', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3716, '12/61 \"PANKI\" 0,5кг', 25000, '', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3717, '12/62 \"PANKI\" 1шт', 2000, '/images/product_3717.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3720, '16/69 MacCoffe Original 75 гр', 17000, '/images/product_3720.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3721, '15/132 kinder supriz', 12000, '/images/product_3721.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3722, '15/133 Raffaello 150 гр', 43000, '/images/product_3722.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3723, '5/41 МАКАРОН ЮЖНАЯ КОРОНА 400 гр (ассортимент)', 4500, '/images/product_3723.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3724, '24/46 Nestle NAN Optipro.1 (400гр)', 77000, '/images/product_3724.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3725, '24/47 Nestle NAN Optipro.2 (400гр)', 77000, '/images/product_3725.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3726, '24/48 Nestle NAN Optipro.3 (400гр)', 77000, '/images/product_3726.png', 1, 0, 3828, 0, '', 1, NULL, NULL, 0, 1, 0),
(3727, '1/38 Булгор калампири (дунган) 1 кг', -78000, '/images/product_3727.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3732, '8/3 Печенье Ёлка шоколанд 1кг', 22000, '', 0, 0, 0, 0, '', 1, NULL, NULL, 0, 1, 0),
(3735, ' 21/67 777 СОВУН DURU', 18000, '', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(3738, '12/63 ойча шакарли печенье', -18000, '/images/product_3738_1607950992.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3739, '10/39 тузланган карам 500 гр', -5000, '/images/product_3739_1607951394.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(3740, '13/31КУРТ \"ERMAK\" 90 ГР.', 6000, '/images/product_3740_1608538199.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3741, '5/42 BIG BON гавядина соус лапша ', 6000, '/images/product_3741_1608621363.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3742, '5/43 BIG BON курица соус сальса лапша', 6000, '/images/product_3742_1608621417.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3743, 'Освежитель Air time тропик', 10000, '/images/product_3743_1608621746.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3744, '5/44 ROLLTON острая лапша с говядиной', 5000, '/images/product_3744_1608621483.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3745, '5/45 ROLLTON  с куриная острая лапша ', 5000, '/images/product_3745_1608621522.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3746, 'Освежитель Air time лиля', 10000, '/images/product_3746_1608621840.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3747, '6/15 Гурунч Лазер  (Тоза) 500 гр', 8500, '/images/product_3747_1609141481.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3748, '1/39- Айзберк Карам 1 дона', -20000, '/images/product_3748_1609126683.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3749, '15/134 Шоколанд Millennium оқ', 11000, '/images/product_3749_1609127124.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3750, '12/64 Яшкино вафли с орешками', 7500, '/images/product_3750_1609590390.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3751, '12/65 Яшкино рулет клубничные 5 штук ', 9500, '/images/product_3751_1609590590.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3752, '12/66 Яшкино вафли шоколанд 200 гр', 7000, '/images/product_3752_1609590717.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3753, '12/67 Яшкино печенье клубника 137 гр', 7500, '/images/product_3753_1609591044.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3755, '18/94 сок tip-top олма 100% 1 лт', 10000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3756, '18/95 сок tip-top мультифрукт 1 лт  ', 10000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3757, '18/96 сок tip-top шафтоли 1 лт ', 10000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3758, '18/97 сок tip-top  анор 100% 1 лт ', 10000, '', 1, 0, 2471, 0, '', 1, NULL, NULL, 0, 1, 0),
(3759, '11/37 Ер Ёнгок магизи 200 г', -8000, '/images/product_3759.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3760, '5/46-Ун  Дани  1-сорт 25 кг', 135000, '/images/product_3760_1610346683.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3761, '16/70 BAYCE кук 25 пакетчали', 5000, '/images/product_3761_1610529467.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3762, '16/71 BAYCE кора олма 25 пакетчали', 8000, '/images/product_3762_1610529922.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3763, '16/72 BAYCE кора шафтоли  25 пакетчали', 8000, '/images/product_3763_1610531262.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3764, '16/73 Чой TESS blueberry tart 20 пакетча', 18000, '/images/product_3764_1610535648.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3765, '16/74 Чой TESS daiquiri breeze 20 пакетча', 18000, '/images/product_3765_1610535940.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3766, '16/75 Чой TESS ginger mojito 20 пакетча', 18000, '/images/product_3766_1610535959.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3767, '16/76 Чой TESS pleasure 100гр ', 15000, '/images/product_3767_1610536702.png', 1, 0, 2350, 0, 'чёрный чай с шиповником и яблоком', 1, NULL, NULL, 0, 1, 0),
(3768, '16/77 Чой TESS earl grey 100гр ', 15000, '/images/product_3768_1610536715.png', 1, 0, 2350, 0, 'чёпнқй чай цедра цитрусовқх аромат бергамота', 1, NULL, NULL, 0, 1, 0),
(3769, '16/78 IMPRA ROYAL ELIXIR TEA 100gr ', 20000, '/images/product_3769_1610539586.png', 1, 0, 2350, 0, 'кук чой', 1, NULL, NULL, 0, 1, 0),
(3770, '16/79 IMPRA ROYAL ELIXIR TEA 100gr ', 20000, '/images/product_3770_1610539598.png', 1, 0, 2350, 0, 'кора чой', 1, NULL, NULL, 0, 1, 0),
(3771, '16/80 IMPRA classic кора чой 90gr ', 18000, '/images/product_3771_1610541065.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3772, '16/81 IMPRA classic кук чой 90gr ', 18000, '/images/product_3772_1610541085.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3773, '16/82 TUDOR 100 гр', 15000, '/images/product_3773_1610541314.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3774, '16/83  TUDOR 100 гр', 15000, '/images/product_3774_1610541368.png', 1, 0, 2350, 0, '', 1, NULL, NULL, 0, 1, 0),
(3775, '15/135 STROBAR 40гр ', 3000, '/images/product_3775_1610541908.png', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3776, 'одна розовая стокан котта 1 шт ', 500, '/images/product_3776_1610545429.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3777, 'одна розовая стокан кичкина 1шт', 350, '/images/product_3777_1610545445.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3778, 'YUMOS extra ', 50000, '/images/product_3778_1610545828.png', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3779, 'YUMOS extra ', 50000, '', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3780, ' 10/40 Консерваланган Бодринг 0.700л-банка   ', -9000, '/images/product_3780_1610546235.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(3781, ' 13/32 Семeчки 7 20 ГР', 500, '/images/product_3781_1610546687.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3782, ' 13/33 Семeчки \"7\" 60 ГР', 2500, '/images/product_3782_1610546702.png', 1, 0, 1545, 0, '', 1, NULL, NULL, 0, 1, 0),
(3783, '15/136 .Шоколадная паста Сhococream 900 гр', 45000, '', 1, 0, 2198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3784, '8/17 Майонез \"Оливьез классическое\" 400гр', 12000, '/images/product_3784.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3785, '8/18 Майонез \"Оливьез классическое\" 700 гр', 15000, '/images/product_3785.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3786, '12/68 \"Вафли мини сливочный\"  1кг', 18000, '/images/product_3786.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3787, '12/69 \"Вафли мини сливочный\" 0,5 кг', 9000, '/images/product_3787.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3788, '12/70 \"Вафли мини малиновый\"  1кг', 18000, '/images/product_3788.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3789, '12/71 \"Вафли мини малиновый\"  0,5кг', 9000, '/images/product_3789.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3790, '12/72 \"Вафли мини лимоновый\"  1кг', 18000, '/images/product_3790.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3791, '12/73 \"Вафли мини лимоновый\"  0,5кг', 9000, '/images/product_3791.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3792, '12/74 \"Вафли мини шоколадный крем\"  1кг', 20000, '/images/product_3792.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3793, '8/122 \"Вафли мини шоколадный крем\"  0,5 кг', 10000, '/images/product_3793.png', 0, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3794, '12/75 \"Вафли мини шоколадный крем\"  0,5кг', 10000, '/images/product_3794.png', 1, 0, 1502, 0, '', 1, NULL, NULL, 0, 1, 0),
(3795, '11/38 Бодом 1кг', 75000, '/images/product_3795.png', 1, 0, 1225, 0, '', 1, NULL, NULL, 0, 1, 0),
(3796, '11/39 Курутилган сливаь 500гр ', -13500, '/images/product_3796_1614066679.png', 1, 0, 1228, 0, '', 1, NULL, NULL, 0, 1, 0),
(3797, '5/47 Чучвара (Adnan) 500 гр ', 13000, '/images/product_3797.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3798, '5/48 Чучвара (Adnan) 300 гр ', 8000, '/images/product_3798.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3799, '20/10 Хлеб (дармон) чорний', 5000, '/images/product_3799.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3800, '20/11 Батон қора (чёрный) 370 гр', -4500, '/images/product_3800.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3801, '20/12 Батон оқ (белый) 370 гр', -4500, '/images/product_3801.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3802, '20/13 Хлеб Рижаной (седана) ', 4500, '/images/product_3802_1614668915.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3803, '20/14 Хлеб Рижаной (семечка) ', 4500, '/images/product_3803_1614587066.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3804, '20/15 Вулкан ржаной', -5500, '/images/product_3804_1614668822.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3805, '20/16 Батон  (деревянцкий) ', -4500, '/images/product_3805_1614668780.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3806, '20/17 Саховат Рижаной ', -4500, '/images/product_3806_1614668523.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3807, '20/18 Батон (немецкий)', -4000, '/images/product_3807_1614668478.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3808, '20/19 Булочка сдобные', 4500, '/images/product_3808.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3810, '20/20 Булочка гунча майизли', 4500, '/images/product_3810_1614589384.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3811, '20/21Булочка малаколи', 4500, '/images/product_3811_1614589448.png', 1, 0, 3823, 0, '', 1, NULL, NULL, 0, 1, 0),
(3812, '2/44 \"ANDALUS\" в/колбаса 1кг', 51000, '/images/product_3812.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3813, '2/45 Salari Королевская колбаса  1кг', 50000, '/images/product_3813_1614687315.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3814, '2/46 SHERIN краковская 1шт', 20000, '/images/product_3814_1614687497.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3815, '2/47 Sarafroz Таллинская', 16000, '/images/product_3815_1614687657.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3817, '3/23-куй карека 1кг', 90000, '/images/product_3817.png', 1, 0, 1193, 0, '', 1, NULL, NULL, 0, 1, 0),
(3818, ' 21/68 \"Сolgate Total 12 \"100ml', 21000, '/images/product_3818.png', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(3819, '6/16 горох', 9000, '/images/product_3819.png', 1, 0, 1198, 0, '', 1, NULL, NULL, 0, 1, 0),
(3823, '20/нон маҳсулотлари', 0, '/images/product_3823_1617355779.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3824, '21/Гигиена маҳсулотлари', 0, '', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3825, '22/Хужалик маҳсулотлари', 0, '/images/product_3825_1617356009.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3827, '23/Аёллар гигиена махсулотлари', 0, '/images/product_3827_1617356684.png', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3828, '24/Болалар маҳсулотлари', 0, '', 1, 0, 0, 99, NULL, 1, NULL, NULL, 0, 1, 0),
(3829, '21/69  \"Colgate\" 3/действие  50мл', 6000, '', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(3830, '9/47 Зелёный чай ручной 400г', 4500, '', 1, 0, 3825, 0, '', 1, NULL, NULL, 0, 1, 0),
(3831, '1/40 кук чиснок', 0, '/images/product_3831.png', 1, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0),
(3832, '21/70 бумага жасмин 6 шт', 12000, '', 1, 0, 3824, 0, '', 1, NULL, NULL, 0, 1, 0),
(3833, '5/49 Манная круппа 300г', 5000, '/images/product_3833_1618644071.png', 1, 0, 1197, 0, '', 1, NULL, NULL, 0, 1, 0),
(3834, '8/19 Махеевь кетчуп 700г', 15500, '/images/product_3834_1618644633.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3835, '8/20 Махеевь кетчуп 500г', 13000, '/images/product_3835.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3836, '8/21 Махеевь кетчуп 300г', 9000, '/images/product_3836_1618644656.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3837, '8/22 Махеевь соус терияки  230г', 8000, '/images/product_3837_1618644684.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3839, '8/23 Махеевь соус барбекю 230г ', 8000, '/images/product_3839_1618644698.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3840, '8/24 Махеевь соус кисло-сладкий 230г ', 8000, '/images/product_3840_1618644734.png', 1, 0, 1200, 0, '', 1, NULL, NULL, 0, 1, 0),
(3841, '2/48 Osiyo сосискии с сыром', 25000, '/images/product_3841_1618630171.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3842, '2/49 Osiyo сосискии молочные', 24000, '/images/product_3842_1618630569.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3843, '2/50 Osiyo CANADA сосискии с сыром', 27000, '/images/product_3843_1618630598.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3844, '2/51 TK сосискии с сыром', 24000, '/images/product_3844_1618630239.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3845, '2/52 \"To`xtaniyoz ota\" салями 1шт', -31000, '/images/product_3845_1618630267.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3846, '2/53 \"To`xtaniyoz ota\" покизо масковски  1шт', -35000, '/images/product_3846_1618630285.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3847, '2/54 Мяснов Докторская  1 кг ', -48000, '/images/product_3847_1618630309.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3848, '2/55 Мяснов Для завтрака 1 кг ', -47000, '/images/product_3848_1618630322.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3849, '2/54 Мяснов сервелат 1шт', -34000, '/images/product_3849_1618630456.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3850, '2/55 Котлеты по-КИЕВСКИ 400г', -20000, '/images/product_3850_1618644116.png', 1, 0, 1192, 0, '', 1, NULL, NULL, 0, 1, 0),
(3853, 'БУЛОЧКА ГАМБУРГЕР 10 шт', 9000, '', 0, 0, 1191, 0, '', 1, NULL, NULL, 0, 1, 0);

-- --------------------------------------------------------

--
-- Структура таблицы `provider`
--

CREATE TABLE `provider` (
  `id` int(11) NOT NULL,
  `name` varchar(50) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `provider`
--

INSERT INTO `provider` (`id`, `name`) VALUES
(1, 'Beeline'),
(2, 'UMS'),
(3, 'Ucell'),
(4, 'Uzmobile'),
(5, 'Perfectum Mobile');

-- --------------------------------------------------------

--
-- Структура таблицы `provider_prefix`
--

CREATE TABLE `provider_prefix` (
  `id` int(11) NOT NULL,
  `provider_id` int(11) DEFAULT NULL,
  `prefix` varchar(2) COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Дамп данных таблицы `provider_prefix`
--

INSERT INTO `provider_prefix` (`id`, `provider_id`, `prefix`) VALUES
(1, 1, '90'),
(2, 1, '91'),
(3, 2, '97'),
(4, 3, '93'),
(5, 3, '94'),
(6, 4, '95'),
(7, 4, '99'),
(8, 5, '98');

-- --------------------------------------------------------

--
-- Структура таблицы `region`
--

CREATE TABLE `region` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `polygon` text DEFAULT NULL,
  `neighbors` text DEFAULT NULL,
  `order_no` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `region`
--

INSERT INTO `region` (`id`, `name`, `polygon`, `neighbors`, `order_no`) VALUES
(1, '[Номаълум]', '40.492812158139294,70.92007714840997;40.49253783726161,70.92631599205015;40.4975570895297,70.93224636891773;40.49769733023677,70.93624555529482;40.5016931580655,70.94622065529484;40.502873824330216,70.96292697250692;40.50379342041456,70.97328181877151;40.509056157169965,70.9753418552948;40.51045058771686,70.97688113014829;40.51602115632273,70.98219695529474;40.52589015512207,70.98362829339317;40.530371302649435,70.9821081161499;40.53521193836112,70.98015127055862;40.539607920731186,70.98925917242195;40.540024505321384,70.99233636453334;40.54189644463173,70.99161823088866;40.54324322434195,70.9910831858283;40.54351531223551,70.99253973659938;40.54365926212082,70.99438277668719;40.54437391517661,70.99423025326769;40.54437391517661,70.99423025326769;40.54388093667661,70.99078118369266;40.546695813383025,70.98949921339272;40.545787880591504,70.98452377847468;40.54944277219377,70.98323769065428;40.55038971788369,70.97856060438562;40.55533037773018,70.97459127817035;40.55653483735257,70.97560787827774;40.5589782530891,70.97439288048486;40.56054128781633,70.97712609436189;40.563270150572066,70.97851837529493;40.5657344554572,70.9699961977999;40.57009614734527,70.95586457987747;40.57289207293191,70.94552278518677;40.5742417087102,70.93535176364412;40.574329774782676,70.93335615765795;40.574809001868104,70.93033058341007;40.58298314817117,70.91274839529478;40.574517149202414,70.9061694052948;40.56409014227287,70.9072208404541;40.556648498659214,70.91004137542018;40.55155384441719,70.91148861937063;40.55022225123498,70.90639185009013;40.54545026319194,70.89257253709297;40.54260743994422,70.8944060237543;40.540883022927375,70.89103478006655;40.53563615393607,70.89126842529481;40.52914480093964,70.87843753581978;40.52597376169802,70.87978389385898;40.52549729802444,70.87613335194669;40.52464568945596,70.87456420422973;40.5180005491129,70.88830993612214;40.5139649040174,70.89690582670596;40.51229904883994,70.90516628942578;40.507469340467786,70.91352939605713;40.50058110869493,70.9193268709318', NULL, -1),
(2, 'Навоий', '40.53521193836112,70.98015127055862;40.539607920731186,70.98925917242195;40.540024505321384,70.99233636453334;40.54189644463173,70.99161823088866;40.54324322434195,70.9910831858283;40.54351531223551,70.99253973659938;40.54365926212082,70.99438277668719;40.54437391517661,70.99423025326769;40.54437391517661,70.99423025326769;40.54388093667661,70.99078118369266;40.546695813383025,70.98949921339272;40.545787880591504,70.98452377847468;40.54944277219377,70.98323769065428;40.55038971788369,70.97856060438562;40.54661013399545,70.96806057181561;40.5448848764123,70.96901893615723;40.54322168253776,70.96421241760254;40.54043329427065,70.9662938117981;40.535214945909665,70.96796751022339;40.536128186214434,70.96987724304199;40.5364706481195,70.97144365310669;40.53506817398536,70.97193717956543;40.53534540957246,70.97373962402344;40.53386137041809,70.9742331504821', '1', 0),
(3, 'Дегрезлик', '40.53953641957307,70.9638261795044;40.537612175160646,70.95689535140991;40.53699249146596,70.9542989730835;40.53141508028686,70.95635890960693;40.531936963008825,70.96198081970215;40.53327426893154,70.9668302536010', NULL, 0),
(5, 'Тухлимерган', '40.52939274634882,70.96820354461602;40.529947263340226,70.97047805786133;40.530371302649435,70.9821081161499;40.52589015512207,70.98362829339317;40.51602115632273,70.98219695529474;40.51045058771686,70.97688113014829;40.51353814357382,70.97464084625244;40.513440264010505,70.97275257110596;40.51745320894504,70.96992015838623;40.518627683977535,70.96790313720703;40.52422247005168,70.96577882766724;40.5266527126893,70.9650278091430', '', 0),
(6, 'Космонавт', '40.5202099303091,70.95303297042847;40.518953923390676,70.9553074836731;40.51667021415951,70.9555435180664;40.516017711519595,70.95412731170654;40.51437011409327,70.9555435180664;40.51303243095877,70.95683097839355;40.513562613442346,70.95786094665527;40.518627683977535,70.96790313720703;40.52422247005168,70.96577882766724;40.52345586516616,70.96335411071777;40.525706722673974,70.96240997314453;40.524760719306556,70.95949172973633;40.52552730926823,70.95921277999878;40.5244671293397,70.95354795455933;40.52329275661255,70.95133781433105;40.521792139296345,70.9513378143310', NULL, 0),
(7, 'Чорсу', '40.53699249146596,70.9542989730835;40.53634018664778,70.95395565032959;40.53710664415619,70.95266819000244;40.53743279362796,70.950608253479;40.53710664415619,70.94874143600464;40.536258648098965,70.94822645187378;40.53619341718843,70.94681024551392;40.53296440773969,70.94610214233376;40.53087688447282,70.94732522964478;40.52932750875406,70.94809770584106;40.53141508028686,70.9563589096069', NULL, 0),
(8, 'Янгичорсу', '40.537693712062186,70.94786167144775;40.5370495678354,70.94712138175964;40.53619341718843,70.94681024551392;40.536258648098965,70.94822645187378;40.53710664415619,70.94874143600464;40.53743279362796,70.950608253479;40.53710664415619,70.95266819000244;40.53634018664778,70.95395565032959;40.53699249146596,70.9542989730835;40.53699249146596,70.9542989730835;40.537612175160646,70.95689535140991;40.53902071118484,70.9556320309639;40.53990740101781,70.95638573169708;40.541167091910204,70.95925569534302;40.54349888438479,70.95805406570435;40.54327060059411,70.95592975616455;40.54235745765114,70.95391273498535;40.54408589627401,70.95249652862549;40.543759779192925,70.95170259475708;40.54144430225985,70.9462308883667;40.53955272649292,70.9468746185302', NULL, 0),
(9, 'Автовокзал', '40.52932750875406,70.94809770584106;40.52329275661255,70.95133781433105;40.5244671293397,70.95354795455933;40.5244671293397,70.95354795455933;40.52552730926823,70.95921277999878;40.53141508028686,70.9563589096069', '6;7;', 0),
(10, 'Бакачорсу', '40.50379342041456,70.97328181877151;40.509056157169965,70.9753418552948;40.51045058771686,70.97688113014829;40.51353814357382,70.97464084625244;40.513440264010505,70.97275257110596;40.51745320894504,70.96992015838623;40.518627683977535,70.96790313720703;40.513562613442346,70.95786094665527;40.502873824330216,70.9629269725069', '6;', 0),
(11, 'ЧПК', '40.516017711519595,70.95412731170654;40.51667021415951,70.9555435180664;40.518953923390676,70.9553074836731;40.5202099303091,70.95303297042847;40.521792139296345,70.95133781433105;40.52329275661255,70.95133781433105;40.52200418508567,70.94629526138306;40.52187369544856,70.94511508941605;40.52203680745524,70.94429969787598;40.52079714624996,70.94357013702393;40.51864399598589,70.94341993331909;40.518285130885104,70.94605922698975;40.515397828129736,70.94616651535034;40.51453324435714,70.94863414764404;40.51456994861183,70.95072090625763;40.51232279553565,70.95315098762512;40.51303243095877,70.95683097839355;40.51437011409327,70.9555435180659', NULL, 0),
(12, 'Химик', '40.51105848393166,70.94026565551758;40.51373390227182,70.94112396240234;40.51507157141209,70.94138145446777;40.51872555596815,70.94146728515625;40.51864399598589,70.94341993331909;40.52079714624996,70.94357013702393;40.52097657231704,70.93777656555176;40.520095748834365,70.93663930892944;40.5193454085908,70.93741178512573;40.51877449190989,70.93739032745361;40.51885605173341,70.93520164489746;40.517339022775026,70.9347939491272;40.51670283912481,70.93507289886475;40.51469637422419,70.9345042705533', NULL, 0),
(13, 'Гишткуприк', '40.53619341718843,70.94681024551392;40.53726971909055,70.94301223754883;40.537090336640944,70.94183206558228;40.534872477586184,70.94215393066406;40.5341549192323,70.93773365020752;40.5330622587972,70.93806624412537;40.53095842957098,70.93891382217407;40.530403920946696,70.94159603118896;40.53032237517375,70.9432053565979;40.53087688447282,70.94732522964478;40.53296440773969,70.9461021423337', '', 0),
(14, '40 лет', '40.5265222321017,70.94198226928711;40.528854534292755,70.94133853912354;40.527288801916114,70.93923568725586;40.52735404149547,70.93850612640381;40.52507061843193,70.93545913696289;40.52286867251558,70.93271255493164;40.520095748834365,70.93663930892944;40.52097657231704,70.93777656555176;40.52079714624996,70.94357013702393;40.52203680745524,70.94429969787598;40.52187369544856,70.94511508941605;40.523863634813786,70.9434413909912', '12;13;15;35;37;', 0),
(15, 'Вокзал', '40.520095748834365,70.93663930892944;40.5193454085908,70.93741178512573;40.51877449190989,70.93739032745361;40.51885605173341,70.93520164489746;40.517339022775026,70.9347939491272;40.51670283912481,70.93507289886475;40.51469637422419,70.93450427055336;40.5198021384349,70.92715501785278;40.52156378154233,70.92339992523193;40.52303178210117,70.92541694641113;40.5242877126158,70.92876434326172;40.52498906616944,70.93442916870117;40.52507061843193,70.93545913696289;40.52286867251558,70.9327125549316', '12;14;35;', 0),
(16, 'Бабушкин', '40.50662096940029,70.92867851257324;40.49769733023677,70.93624555529482;40.5016931580655,70.94622065529484;40.509590221186414,70.94391345977783;40.51105848393166,70.94026565551758;40.51469637422419,70.93450427055336;40.5198021384349,70.92715501785278;40.52156378154233,70.92339992523193;40.52342324348721,70.92080354690552;40.524075674050174,70.91065406799316;40.52321527991058,70.89553177356697;40.5180005491129,70.88830993612214;40.5139649040174,70.89690582670596;40.51229904883994,70.90516628942578;40.507469340467786,70.91352939605713;40.50851347474201,70.9210824966430', '12;14;15;17;', 0),
(17, 'Авғонбог', '40.507469340467786,70.91352939605713;40.50851347474201,70.92108249664307;40.50662096940029,70.92867851257324;40.49769733023677,70.93624555529482;40.4975570895297,70.93224636891773;40.49253783726161,70.92631599205015;40.492812158139294,70.92007714840997;40.50058110869493,70.9193268709318', '16;', 0),
(18, 'Дилшод', '40.537090336640944,70.94183206558228;40.534872477586184,70.94215393066406;40.5341549192323,70.93773365020752;40.5330622587972,70.93806624412537;40.5330622587972,70.93806624412537;40.53232837238298,70.93494951725006;40.53152108804372,70.93500852584839;40.53022452011526,70.93573808670044;40.53056701219484,70.93494415283203;40.53077087569687,70.9323799610138;40.53424461444676,70.93127489089966;40.53824000674279,70.92998206615448;40.53961795413267,70.93116760253906;40.539308122278264,70.9316611289978;40.54005823903967,70.93445062637306;40.54092249359011,70.9352445602417;40.541232317978,70.93846321105957;40.54155844736454,70.93833446502686;40.54185196245484,70.94000816345215;40.54178673699035,70.94101667404175;40.54141984256925,70.9411668777463', NULL, 0),
(19, 'Хокимият', '40.53507632798958,70.92251479625702;40.53272589518845,70.92372179031372;40.53123568216246,70.92449426651001;40.530306066007256,70.9246015548706;40.52993095408244,70.92453718185425;40.530518084862074,70.92702627182007;40.530550703087876,70.92799186706543;40.53006142803356,70.92805624008179;40.530028809569615,70.92887163162231;40.53077087569687,70.9323799610138;40.53424461444676,70.93127489089966;40.53824000674279,70.92998206615448;40.537832324567134,70.92775583267212;40.536552186410304,70.92655420303345;40.53585095386631,70.9273910522458', '', 0),
(20, 'Чархий', '40.55659128824991,70.91661930084206;40.560177801500245,70.92069625854492;40.55655868270271,70.92769145965576;40.55509141664332,70.92859268188477;40.556330443427605,70.93292713165283;40.556330443427605,70.93292713165283;40.554634927311255,70.9337854385376;40.55443928807334,70.9332275390625;40.55381976004866,70.9335708618164;40.55378715315173,70.93425750732422;40.55181440634687,70.9353518486023;40.551048117122214,70.93438625335693;40.54909159421943,70.9326696395874;40.54896115732679,70.93382835388184;40.547493724778576,70.93262672424316;40.547037183650254,70.93365669250488;40.54514576582186,70.93194007873535;40.54310754026728,70.93548059463501;40.54194980053248,70.92983722686768;40.53800762820663,70.92061042785645;40.54043329427065,70.92031002044678;40.54102033302531,70.91996669769287;40.54273250000914,70.92013835906982;40.5531024046482,70.92254161834717;40.55489577873924,70.9203529357910', NULL, 0),
(21, '10 Автобаза', '40.560177801500245,70.92069625854492;40.55655868270271,70.92769145965576;40.55509141664332,70.92859268188477;40.556330443427605,70.93292713165283;40.55717818538439,70.93477249145508;40.558678010242666,70.93430042266846;40.55834381304775,70.93654274940491;40.5742417087102,70.93535176364412;40.574329774782676,70.9333561576579', '20;22;28;41;48;49;', 0),
(22, 'Тулабой', '40.55650977435207,70.94698190689087;40.55549899377414,70.94728231430054;40.55566202393176,70.94831228256226;40.55580875073422,70.94949245452881;40.556102203374444,70.95035076141357;40.55659128824993,70.94994306564331;40.55667280204851,70.95157384872437;40.5589062415146,70.95155239105225;40.559884366724184,70.9511661529541;40.56721985024933,70.95258235931396;40.567708853900555,70.95610141754105;40.57009614734527,70.95586457987747;40.57009614734527,70.95586457987747;40.57289207293191,70.94552278518677;40.569713731514454,70.94541549682617;40.569012846169,70.94558715820312;40.56824675379004,70.94638109207153;40.56764365362016,70.94640254974365;40.56664934147369,70.94693899154663;40.564660672863596,70.94708919525146;40.5607402145591,70.94732522964478;40.559101867699844,70.94822645187378;40.5565016229569,70.9487199783325', '', 0),
(23, 'Оптом', '40.5657344554572,70.9699961977999;40.563270150572066,70.97851837529493;40.56054128781633,70.97712609436189;40.5589782530891,70.97439288048486;40.55653483735257,70.97560787827774;40.55533037773018,70.97459127817035;40.55553159983743,70.9731388092041;40.55408061465244,70.96936225891113;40.55143941484322,70.96957683563232;40.55075464233096,70.96867561340332;40.5506568171147,70.96717357635498;40.54830896905275,70.96648693084717;40.549776383737715,70.96341848373413;40.55150463090774,70.96095085144043;40.55303719013979,70.95959901809692;40.55486317236636,70.95779657363892;40.559395305905845,70.96442699432373;40.55877582374019,70.96541404724121;40.560569045867474,70.97073554992676;40.563209885535954,70.97099304199219;40.56487258298723,70.9697484970092', NULL, 0),
(24, '65 автобаза', '40.55150463090774,70.96095085144043;40.549776383737715,70.96341848373413;40.544982710059955,70.95846176147461;40.54439570603039,70.95760345458984;40.54349888438479,70.95805406570435;40.54327060059411,70.95592975616455;40.54235745765114,70.95391273498535;40.54408589627401,70.95249652862549;40.543759779192925,70.95170259475708;40.54527621014555,70.95144510269165;40.54658063940975,70.95170259475708;40.547624164529346,70.95511436462402;40.548178530635774,70.95532894134521;40.548749196834386,70.95489978790283;40.55303719013979,70.9595990180969', NULL, 0),
(25, 'Гозиёглик', '40.53563615393607,70.89126842529481;40.540883022927375,70.89103478006655;40.54260743994422,70.8944060237543;40.54545026319194,70.89257253709297;40.55022225123498,70.90639185009013;40.547787213860545,70.90902328491211;40.54853723567113,70.91043949127197;40.547950262794764,70.91168403625488;40.54827635947232,70.91365814208984;40.54384130861204,70.91623306274414;40.54429787152531,70.9173059463501;40.54312384631782,70.91880798339844;40.543221682537734,70.9196662902832;40.54273250000914,70.92013835906982;40.54102033302531,70.91996669769287;40.53969948859302,70.91833591461182;40.53455854675191,70.91780483722687;40.53346079652388,70.91199919581413;40.53599160865692,70.91037780046463;40.538582457853124,70.90881943702698;40.53734310268151,70.9066253900528;40.536674493660485,70.90410947799683;40.53578024662863,70.8975602056132', '', 0),
(26, 'Романка', '40.52993095408244,70.92453718185425;40.530306066007256,70.9246015548706;40.53123568216246,70.92449426651001;40.53272589518845,70.92372179031372;40.53507632798958,70.92251479625702;40.536751954803435,70.9211415052414;40.53800762820663,70.92061042785645;40.54043329427065,70.92031002044678;40.54102033302531,70.91996669769287;40.53969948859302,70.91833591461182;40.53455854675191,70.91780483722687;40.53346079652388,70.91199919581413;40.53274831948153,70.91233313083649;40.53386544749375,70.91820180416107;40.53179018390407,70.92018127441406;40.531936963008825,70.92153310775757;40.531072592541676,70.92176914215088;40.53068117583238,70.92091083526611;40.5287566770909,70.9216189384460', NULL, 0),
(27, 'Астепа', '40.5180005491129,70.88830993612214;40.52464568945596,70.87456420422973;40.52549729802444,70.87613335194669;40.52597376169802,70.87978389385898;40.52914480093964,70.87843753581978;40.53563615393607,70.89126842529481;40.53578024662863,70.89756020561322;40.536674493660485,70.90410947799683;40.53734310268151,70.9066253900528;40.538582457853124,70.90881943702698;40.53599160865692,70.91037780046463;40.53346079652388,70.91199919581413;40.53274831948153,70.91233313083649;40.52534789538222,70.91726303100586;40.52342324348721,70.92080354690552;40.524075674050174,70.91065406799316;40.52321527991058,70.8955317735669', '25;26;36;', 0),
(28, 'Дангара', '40.556648498659214,70.91004137542018;40.56409014227287,70.9072208404541;40.574517149202414,70.9061694052948;40.58298314817117,70.91274839529478;40.574809001868104,70.93033058341007;40.574329774782676,70.93335615765795;40.560177801500245,70.92069625854492;40.55659128824991,70.9166193008420', '', 0),
(29, 'Айрилиш', '40.549776383737715,70.96341848373413;40.54830896905275,70.96648693084717;40.54661013399545,70.96806057181561;40.5448848764123,70.96901893615723;40.54322168253776,70.96421241760254;40.541167091910204,70.95925569534302;40.54349888438479,70.95805406570435;40.54439570603039,70.95760345458984;40.544982710059955,70.9584617614746', '2;8;23;43;', 0),
(31, 'Динам', '40.529947263340226,70.97047805786133;40.530371302649435,70.9821081161499;40.53521193836112,70.98015127055862;40.53386137041809,70.97423315048218;40.53534540957246,70.97373962402344;40.53506817398536,70.97193717956543;40.5364706481195,70.97144365310669;40.536128186214434,70.96987724304199;40.535214945909665,70.96796751022339;40.54043329427065,70.9662938117981;40.53953641957307,70.9638261795044;40.53327426893154,70.96683025360107;40.52939274634882,70.9682035446160', NULL, 0),
(32, 'Охак бозори', '40.53141508028686,70.95635890960693;40.531936963008825,70.96198081970215;40.53327426893154,70.96683025360107;40.52939274634882,70.96820354461602;40.5266527126893,70.96502780914307;40.52422247005168,70.96577882766724;40.52345586516616,70.96335411071777;40.524401886950216,70.96296787261963;40.525706722673974,70.96240997314453;40.524760719306556,70.95949172973633;40.52552730926823,70.9592127799985', '', 0),
(33, 'Калвак', '40.52200418508567,70.94629526138306;40.52329275661255,70.95133781433105;40.52932750875406,70.94809770584106;40.53087688447282,70.94732522964478;40.53032237517375,70.9432053565979;40.530403920946696,70.94159603118896;40.528854534292755,70.94133853912354;40.5265222321017,70.94198226928711;40.523863634813786,70.94344139099121;40.52187369544856,70.9451150894160', NULL, 0),
(34, 'Большевик', '40.51864399598589,70.94341993331909;40.51864399598589,70.94341993331909;40.51872555596815,70.94146728515625;40.51507157141209,70.94138145446777;40.51373390227182,70.94112396240234;40.51105848393166,70.94026565551758;40.509590221186414,70.94391345977783;40.5016931580655,70.94622065529484;40.502873824330216,70.96292697250692;40.513562613442346,70.95786094665527;40.51303243095877,70.95683097839355;40.51232279553565,70.95315098762512;40.51456994861183,70.95072090625763;40.51453324435714,70.94863414764404;40.515397828129736,70.94616651535034;40.518285130885104,70.9460592269897', '11;12;15;', 0),
(35, 'Гиштли масжид', '40.52303178210117,70.92541694641113;40.5242877126158,70.92876434326172;40.52498906616944,70.93442916870117;40.52552730926823,70.93419313430786;40.52683212308247,70.93481540679932;40.52821845992648,70.9351372718811;40.52903393879172,70.93590974807739;40.53022452011526,70.93573808670044;40.53056701219484,70.93494415283203;40.53077087569687,70.9323799610138;40.530028809569615,70.92887163162231;40.53006142803356,70.92805624008179;40.530550703087876,70.92799186706543;40.530518084862074,70.92702627182007;40.52993095408244,70.92453718185425;40.5287566770909,70.92161893844604;40.527598689352445,70.92172622680664;40.5255109989348,70.9229278564453', '', 0),
(36, 'МЖК', '40.52156378154233,70.92339992523193;40.52303178210117,70.92541694641113;40.5255109989348,70.92292785644531;40.527598689352445,70.92172622680664;40.5287566770909,70.92161893844604;40.53068117583238,70.92091083526611;40.531072592541676,70.92176914215088;40.531936963008825,70.92153310775757;40.53179018390407,70.92018127441406;40.53386544749375,70.91820180416107;40.53274831948153,70.91233313083649;40.53274831948153,70.91233313083649;40.52534789538222,70.91726303100586;40.52342324348721,70.9208035469055', NULL, 0),
(37, 'Горгаз', '40.53095842957098,70.93891382217407;40.530403920946696,70.94159603118896;40.528854534292755,70.94133853912354;40.528854534292755,70.94133853912354;40.527288801916114,70.93923568725586;40.52735404149547,70.93850612640381;40.52507061843193,70.93545913696289;40.52498906616944,70.93442916870117;40.52552730926823,70.93419313430786;40.52683212308247,70.93481540679932;40.52821845992648,70.9351372718811;40.52903393879172,70.93590974807739;40.53022452011526,70.93573808670044;40.53152108804372,70.93500852584839;40.53232837238298,70.93494951725006;40.5330622587972,70.93806624412537;40.5330622587972,70.9380662441253', NULL, 0),
(38, 'Мелкомбинат', '40.55022225123498,70.90639185009013;40.547787213860545,70.90902328491211;40.54853723567113,70.91043949127197;40.547950262794764,70.91168403625488;40.54827635947232,70.91365814208984;40.54384130861204,70.91623306274414;40.54429787152531,70.9173059463501;40.54312384631782,70.91880798339844;40.543221682537734,70.9196662902832;40.54273250000914,70.92013835906982;40.5531024046482,70.92254161834717;40.55489577873924,70.92035293579102;40.55659128824991,70.91661930084206;40.556648498659214,70.91004137542018;40.55155384441719,70.9114886193706', NULL, 0),
(39, 'Зелёний', '40.53585095386631,70.9273910522461;40.53507632798958,70.92251479625702;40.536751954803435,70.9211415052414;40.53800762820663,70.92061042785645;40.54194980053248,70.92983722686768;40.53961795413267,70.93116760253906;40.53824000674279,70.92998206615448;40.537832324567134,70.92775583267212;40.536552186410304,70.9265542030334', NULL, 0),
(41, 'Ипак йўли', '40.55834381304775,70.93654274940491;40.556738013015845,70.94290494918823;40.556460865965796,70.94517946243286;40.55650977435207,70.94698190689087;40.5565016229569,70.94871997833252;40.559101867699844,70.94822645187378;40.5607402145591,70.94732522964478;40.564660672863596,70.94708919525146;40.56664934147369,70.94693899154663;40.56764365362016,70.94640254974365;40.56824675379004,70.94638109207153;40.569012846169,70.94558715820312;40.569713731514454,70.94541549682617;40.57289207293191,70.94552278518677;40.57289207293191,70.94552278518677;40.5742417087102,70.9353517636441', NULL, 0),
(42, 'Шиша бозор', '40.57009614734527,70.95586457987747;40.5657344554572,70.9699961977999;40.56487258298723,70.96974849700928;40.563209885535954,70.97099304199219;40.560569045867474,70.97073554992676;40.55877582374019,70.96541404724121;40.559395305905845,70.96442699432373;40.55486317236636,70.95779657363892;40.55618371776846,70.95650911331177;40.556754315747774,70.95472812652588;40.55667280204851,70.95157384872437;40.5589062415146,70.95155239105225;40.559884366724184,70.9511661529541;40.56721985024933,70.95258235931396;40.567708853900555,70.9561014175410', NULL, 0),
(43, 'Саодат масжиди', '40.55038971788369,70.97856060438562;40.54661013399545,70.96806057181561;40.54830896905275,70.96648693084717;40.5506568171147,70.96717357635498;40.55075464233096,70.96867561340332;40.55143941484322,70.96957683563232;40.55408061465244,70.96936225891113;40.55553159983743,70.9731388092041;40.55533037773018,70.9745912781702', NULL, 0),
(44, 'Утинбозор', '40.54322168253776,70.96421241760254;40.54043329427065,70.9662938117981;40.53953641957307,70.9638261795044;40.537612175160646,70.95689535140991;40.53902071118484,70.9556320309639;40.53990740101781,70.95638573169708;40.541167091910204,70.9592556953430', '', 0),
(45, 'Урганжибоғ', '40.556102203374444,70.95035076141357;40.55580875073422,70.94949245452881;40.55566202393176,70.94831228256226;40.55549899377414,70.94728231430054;40.55458601755535,70.94745397567749;40.55388497379489,70.94818353652954;40.55279263516758,70.9471321105957;40.55153723891619,70.94775438308716;40.549336162708364,70.94848394393921;40.54907528962175,70.95247507095337;40.54658063940975,70.95170259475708;40.547624164529346,70.95511436462402;40.548178530635774,70.95532894134521;40.548749196834386,70.95489978790283;40.55303719013979,70.95959901809692;40.55486317236636,70.95779657363892;40.55618371776846,70.95650911331177;40.556754315747774,70.95472812652588;40.55667280204851,70.95157384872437;40.55659128824993,70.94994306564331;40.55659128824993,70.9499430656433', NULL, 0),
(46, 'Арчазор', '40.549336162708364,70.94848394393921;40.54907528962175,70.95247507095337;40.54658063940975,70.95170259475708;40.54527621014555,70.95144510269165;40.543759779192925,70.95170259475708;40.54144430225985,70.9462308883667;40.54266727540205,70.94485759735107;40.54439570603039,70.94436407089233;40.54635236612245,70.94226121902466;40.548194835451795,70.94099521636963;40.548113311332024,70.93814134597778;40.549743774871814,70.93702554702759;40.55052638327075,70.93921422958374;40.55054268751514,70.942862033844;40.55153723891619,70.9477543830871', '45;49;', 0),
(47, 'Педколлеж', '40.548113311332024,70.93814134597778;40.548194835451795,70.94099521636963;40.54635236612245,70.94226121902466;40.54439570603039,70.94436407089233;40.54266727540205,70.94485759735107;40.54144430225985,70.9462308883667;40.54127308423813,70.94424605369568;40.54155029414922,70.94279766082764;40.54141984256925,70.94116687774658;40.54178673699035,70.94101667404175;40.54243898877714,70.94060897827148;40.5479339579192,70.9374332427978', NULL, 0),
(48, 'Водоканал', '40.558678010242666,70.93430042266846;40.55717818538439,70.93477249145508;40.556330443427605,70.93292713165283;40.554634927311255,70.9337854385376;40.55443928807334,70.9332275390625;40.55381976004866,70.9335708618164;40.55378715315173,70.93425750732422;40.55181440634687,70.9353518486023;40.5479339579192,70.93743324279785;40.548113311332024,70.93814134597778;40.549743774871814,70.93702554702759;40.55052638327075,70.93921422958374;40.55054268751514,70.942862033844;40.55153723891619,70.94775438308716;40.55279263516758,70.9471321105957;40.55388497379489,70.94818353652954;40.55458601755535,70.94745397567749;40.55549899377414,70.94728231430054;40.55650977435207,70.94698190689087;40.556460865965796,70.94517946243286;40.556738013015845,70.94290494918823;40.55834381304775,70.9365427494049', '20;21;49;', 0),
(49, 'Спортивный', '40.54092249359011,70.9352445602417;40.54121601146699,70.9382700920105;40.541232317978,70.93846321105957;40.54155844736454,70.93833446502686;40.54185196245484,70.94000816345215;40.54178673699035,70.94101667404175;40.54243898877714,70.94060897827148;40.5479339579192,70.93743324279785;40.55181440634687,70.9353518486023;40.551048117122214,70.93438625335693;40.54909159421943,70.9326696395874;40.54896115732679,70.93382835388184;40.547493724778576,70.93262672424316;40.547037183650254,70.93365669250488;40.54514576582186,70.93194007873535;40.54310754026728,70.93548059463501;40.54194980053248,70.92983722686768;40.53961795413267,70.93116760253906;40.539308122278264,70.9316611289978;40.54005823903967,70.9344506263730', NULL, 0),
(50, 'Ярмарка', NULL, NULL, 0),
(51, 'Сарботир', NULL, NULL, 0),
(53, 'Каппон бозор', '', '', 0),
(54, 'Автодорож', NULL, NULL, 0),
(55, 'Саланг', NULL, NULL, 0),
(56, 'Артизон буйи', NULL, NULL, 0),
(57, 'Ёйилма', NULL, NULL, 0),
(58, 'Найманча', NULL, NULL, 0),
(59, 'Экстренный', NULL, NULL, 0),
(60, 'Шайхон', NULL, NULL, 0),
(61, 'Силикат', NULL, NULL, 0),
(62, 'Городок', '', '', 0),
(63, 'Чодаклик', '', '', 0),
(64, 'Компьютер коллеж', '', '', 0),
(66, 'Горотдел', '', '', 0);

-- --------------------------------------------------------

--
-- Структура таблицы `sms`
--

CREATE TABLE `sms` (
  `id` int(11) NOT NULL,
  `type` int(11) DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `order_id` int(11) DEFAULT NULL,
  `text` varchar(320) DEFAULT '',
  `phone` varchar(20) DEFAULT NULL,
  `code` varchar(6) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `sms`
--

INSERT INTO `sms` (`id`, `type`, `status`, `date`, `order_id`, `text`, `phone`, `code`) VALUES
(773, 5, 0, '2019-07-20 12:48:49', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 58000 ', '+998905087179', NULL),
(774, 5, 0, '2019-07-20 12:48:49', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 58000 ', '+998945568386', NULL),
(775, 5, 0, '2019-07-20 12:48:50', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 58000 ', '+998905860585', NULL),
(776, 5, 0, '2019-07-20 12:48:50', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 58000 ', '+998905076239', NULL),
(777, 5, 0, '2019-07-20 12:48:50', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 58000 ', '+998990111400', NULL),
(778, 5, 0, '2019-07-20 16:09:31', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 20000 ', '+998905087179', NULL),
(779, 5, 0, '2019-07-20 16:09:31', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 20000 ', '+998945568386', NULL),
(780, 5, 0, '2019-07-20 16:34:18', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 10000 ', '+998974194400', NULL),
(781, 5, 0, '2019-07-20 16:34:18', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 10000 ', '+998974164400', NULL),
(782, 5, 0, '2019-07-20 16:34:18', NULL, 'BarakaTop dan buyurtma tushdi. Mijoz: +998916848100, Summa: 10000 ', '+998911410990', NULL),
(783, 5, 0, '2019-07-21 02:35:53', NULL, 'TAXI: Tasdiqlash kodi - 599459', '+998916848100', NULL);

-- --------------------------------------------------------

--
-- Структура таблицы `tariff`
--

CREATE TABLE `tariff` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `min_sum` double DEFAULT NULL,
  `min_sum_ex` double DEFAULT 0,
  `min_distance` double DEFAULT NULL,
  `min_distance_ex` double DEFAULT 0,
  `min_time` double DEFAULT NULL,
  `for_distance` double DEFAULT NULL,
  `for_distance_ex` double DEFAULT NULL,
  `for_time` double DEFAULT NULL,
  `service1` double DEFAULT 0,
  `service2` double DEFAULT 0,
  `service3` double DEFAULT 0,
  `service4` double DEFAULT 0,
  `service5` double DEFAULT 0,
  `service6` double DEFAULT 0,
  `flags` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `tariff`
--

INSERT INTO `tariff` (`id`, `name`, `min_sum`, `min_sum_ex`, `min_distance`, `min_distance_ex`, `min_time`, `for_distance`, `for_distance_ex`, `for_time`, `service1`, `service2`, `service3`, `service4`, `service5`, `service6`, `flags`) VALUES
(1, 'Оддий', 4000, 5000, 3, 4, 12, 500, 1000, 300, 1000, 1000, 0, 0, 0, 2000, 0),
(2, 'Тезкор', 5000, 5000, 3, 4, 12, 500, 1000, 300, 1000, 1000, 0, 0, 0, 2000, 0),
(3, 'Комфорт', 4000, 5000, 3, 4, 12, 500, 1000, 300, 1000, 1000, 0, 0, 0, 2000, 1),
(4, 'Етказма', 6000, 5000, 5, 4, 12, 500, 1000, 300, 1000, 1000, 0, 0, 0, 2000, 2),
(5, 'Йўловчи', 4500, 5000, 3, 4, 12, 500, 1000, 320, 1000, 1000, 0, 0, 0, 2000, 1);

-- --------------------------------------------------------

--
-- Структура таблицы `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '1 - active, 0 - noactive',
  `email` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Дамп данных таблицы `users`
--

INSERT INTO `users` (`id`, `name`, `username`, `password`, `phone`, `status`, `email`, `email_verified_at`, `remember_token`, `created_at`, `updated_at`) VALUES
(1, 'Admin', 'admin', '$2y$10$u83FMfMtIsYDbIEy.D0AB.dAHyZvGwmqjO2NjwMs91JlQ9HjyargK', '+998332087090', '1', 'admin@gmail.com', NULL, NULL, '2021-09-03 07:29:23', NULL),
(2, 'Omborchi', 'ombor', '$2y$10$gg8jhLv91J5TUd0gsnJTRug0agvFjK8A4TTZ/A67W1cQ4Xi0dJ6Gm', '+998972087080', '1', 'omborchi@gmail.com', NULL, NULL, '2021-09-04 00:29:31', NULL),
(3, 'Dispatcher', 'dispatcher', '$2y$10$gg8jhLv91J5TUd0gsnJTRug0agvFjK8A4TTZ/A67W1cQ4Xi0dJ6Gm', '+998971234568', '1', 'dispacher@gmail.com', NULL, NULL, '2021-09-06 00:29:31', NULL),
(4, 'salom', 'aroba1', '123456', '+998945568386', '1', 'user1633534048@gmail.com', NULL, NULL, '2021-10-06 10:27:28', '2021-10-06 10:27:28');

-- --------------------------------------------------------

--
-- Структура таблицы `user_priv`
--

CREATE TABLE `user_priv` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `action_id` int(11) DEFAULT NULL,
  `access` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `user_priv`
--

INSERT INTO `user_priv` (`id`, `user_id`, `action_id`, `access`) VALUES
(4787, 17, 101, 1),
(4788, 17, 107, 1),
(4789, 17, 106, 1),
(4790, 17, 105, 1),
(4791, 17, 104, 1),
(4792, 17, 103, 1),
(4793, 17, 102, 1),
(4794, 17, 209, 1),
(4795, 17, 208, 1),
(4796, 17, 207, 1),
(4797, 17, 206, 1),
(4798, 17, 205, 1),
(4799, 17, 204, 1),
(4800, 17, 203, 1),
(4801, 17, 202, 1),
(4802, 17, 201, 1),
(4803, 17, 306, 1),
(4804, 17, 305, 1),
(4805, 17, 304, 1),
(4806, 17, 303, 1),
(4807, 17, 302, 1),
(4808, 17, 301, 1),
(4809, 17, 401, 1),
(4810, 17, 402, 1),
(4811, 17, 508, 1),
(4812, 17, 509, 1),
(4813, 17, 510, 1),
(4814, 17, 511, 1),
(4815, 17, 507, 1),
(4816, 17, 506, 1),
(4817, 17, 505, 1),
(4818, 17, 504, 1),
(4819, 17, 503, 1),
(4820, 17, 502, 1),
(4821, 17, 501, 1),
(4822, 17, 601, 1),
(5110, 17, 512, 1),
(5185, 1, 100, 1),
(5186, 1, 101, 1),
(5187, 1, 102, 1),
(5188, 1, 103, 1),
(5189, 1, 104, 1),
(5190, 1, 105, 1),
(5191, 1, 106, 1),
(5192, 1, 107, 1),
(5193, 1, 200, 1),
(5194, 1, 201, 1),
(5195, 1, 202, 1),
(5196, 1, 203, 1),
(5197, 1, 204, 1),
(5198, 1, 205, 1),
(5199, 1, 206, 1),
(5200, 1, 207, 1),
(5201, 1, 208, 1);

--
-- Индексы сохранённых таблиц
--

--
-- Индексы таблицы `action`
--
ALTER TABLE `action`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `address`
--
ALTER TABLE `address`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_name` (`name`) USING BTREE;

--
-- Индексы таблицы `ads`
--
ALTER TABLE `ads`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `bonus`
--
ALTER TABLE `bonus`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `bot`
--
ALTER TABLE `bot`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_chat_id` (`chat_id`);

--
-- Индексы таблицы `bot_user`
--
ALTER TABLE `bot_user`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `car`
--
ALTER TABLE `car`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `car_blacklist`
--
ALTER TABLE `car_blacklist`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `car_color`
--
ALTER TABLE `car_color`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_color` (`name`) USING BTREE;

--
-- Индексы таблицы `car_message`
--
ALTER TABLE `car_message`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `car_model`
--
ALTER TABLE `car_model`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_model` (`name`) USING BTREE;

--
-- Индексы таблицы `car_payment`
--
ALTER TABLE `car_payment`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_unique` (`car_id`,`reason`,`date`,`payment_type_id`) USING BTREE;

--
-- Индексы таблицы `client`
--
ALTER TABLE `client`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_telefon` (`phone`) USING BTREE;

--
-- Индексы таблицы `client_comment`
--
ALTER TABLE `client_comment`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `client_group`
--
ALTER TABLE `client_group`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `client_partner_rating`
--
ALTER TABLE `client_partner_rating`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_rating` (`phone`,`partner_id`);

--
-- Индексы таблицы `client_product_review`
--
ALTER TABLE `client_product_review`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_client_product` (`client_id`,`product_id`);

--
-- Индексы таблицы `config`
--
ALTER TABLE `config`
  ADD PRIMARY KEY (`name`),
  ADD UNIQUE KEY `ix_name` (`name`) USING BTREE;

--
-- Индексы таблицы `config_c`
--
ALTER TABLE `config_c`
  ADD PRIMARY KEY (`name`),
  ADD UNIQUE KEY `ix_name` (`name`) USING BTREE;

--
-- Индексы таблицы `config_p`
--
ALTER TABLE `config_p`
  ADD PRIMARY KEY (`name`),
  ADD UNIQUE KEY `ix_name` (`name`) USING BTREE;

--
-- Индексы таблицы `counter`
--
ALTER TABLE `counter`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `department`
--
ALTER TABLE `department`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `driver`
--
ALTER TABLE `driver`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `failed_jobs`
--
ALTER TABLE `failed_jobs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`);

--
-- Индексы таблицы `message`
--
ALTER TABLE `message`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `message_template`
--
ALTER TABLE `message_template`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `nationality`
--
ALTER TABLE `nationality`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ix_nationality` (`name`) USING BTREE;

--
-- Индексы таблицы `offered_sums`
--
ALTER TABLE `offered_sums`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `region_id` (`region_id`) USING BTREE,
  ADD KEY `driver_id` (`driver_id`) USING BTREE,
  ADD KEY `status` (`status`) USING BTREE;

--
-- Индексы таблицы `order_details`
--
ALTER TABLE `order_details`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `partner`
--
ALTER TABLE `partner`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `partner_group`
--
ALTER TABLE `partner_group`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `password_resets`
--
ALTER TABLE `password_resets`
  ADD KEY `password_resets_email_index` (`email`);

--
-- Индексы таблицы `payment_type`
--
ALTER TABLE `payment_type`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `personal_access_tokens`
--
ALTER TABLE `personal_access_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  ADD KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`);

--
-- Индексы таблицы `photo`
--
ALTER TABLE `photo`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `place`
--
ALTER TABLE `place`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `place_type`
--
ALTER TABLE `place_type`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `plate_pattern`
--
ALTER TABLE `plate_pattern`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `provider`
--
ALTER TABLE `provider`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `provider_prefix`
--
ALTER TABLE `provider_prefix`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `region`
--
ALTER TABLE `region`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `sms`
--
ALTER TABLE `sms`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `tariff`
--
ALTER TABLE `tariff`
  ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `users_username_unique` (`name`),
  ADD UNIQUE KEY `users_email_unique` (`email`);

--
-- Индексы таблицы `user_priv`
--
ALTER TABLE `user_priv`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT для сохранённых таблиц
--

--
-- AUTO_INCREMENT для таблицы `address`
--
ALTER TABLE `address`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8078;

--
-- AUTO_INCREMENT для таблицы `ads`
--
ALTER TABLE `ads`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT для таблицы `bonus`
--
ALTER TABLE `bonus`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `bot`
--
ALTER TABLE `bot`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=160;

--
-- AUTO_INCREMENT для таблицы `bot_user`
--
ALTER TABLE `bot_user`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT для таблицы `car`
--
ALTER TABLE `car`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `car_blacklist`
--
ALTER TABLE `car_blacklist`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=256;

--
-- AUTO_INCREMENT для таблицы `car_color`
--
ALTER TABLE `car_color`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6462;

--
-- AUTO_INCREMENT для таблицы `car_message`
--
ALTER TABLE `car_message`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2175;

--
-- AUTO_INCREMENT для таблицы `car_model`
--
ALTER TABLE `car_model`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10534;

--
-- AUTO_INCREMENT для таблицы `car_payment`
--
ALTER TABLE `car_payment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `client`
--
ALTER TABLE `client`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=114135;

--
-- AUTO_INCREMENT для таблицы `client_comment`
--
ALTER TABLE `client_comment`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=765;

--
-- AUTO_INCREMENT для таблицы `client_group`
--
ALTER TABLE `client_group`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT для таблицы `client_partner_rating`
--
ALTER TABLE `client_partner_rating`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `client_product_review`
--
ALTER TABLE `client_product_review`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=252;

--
-- AUTO_INCREMENT для таблицы `counter`
--
ALTER TABLE `counter`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `department`
--
ALTER TABLE `department`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=32;

--
-- AUTO_INCREMENT для таблицы `driver`
--
ALTER TABLE `driver`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `failed_jobs`
--
ALTER TABLE `failed_jobs`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `message`
--
ALTER TABLE `message`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2315;

--
-- AUTO_INCREMENT для таблицы `message_template`
--
ALTER TABLE `message_template`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT для таблицы `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT для таблицы `nationality`
--
ALTER TABLE `nationality`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT для таблицы `offered_sums`
--
ALTER TABLE `offered_sums`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT для таблицы `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11467;

--
-- AUTO_INCREMENT для таблицы `order_details`
--
ALTER TABLE `order_details`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=96577;

--
-- AUTO_INCREMENT для таблицы `partner`
--
ALTER TABLE `partner`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '1-admin, 2-user', AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT для таблицы `partner_group`
--
ALTER TABLE `partner_group`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT для таблицы `payment_type`
--
ALTER TABLE `payment_type`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT для таблицы `personal_access_tokens`
--
ALTER TABLE `personal_access_tokens`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `photo`
--
ALTER TABLE `photo`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT для таблицы `place`
--
ALTER TABLE `place`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=289;

--
-- AUTO_INCREMENT для таблицы `place_type`
--
ALTER TABLE `place_type`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT для таблицы `plate_pattern`
--
ALTER TABLE `plate_pattern`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT для таблицы `products`
--
ALTER TABLE `products`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3857;

--
-- AUTO_INCREMENT для таблицы `provider`
--
ALTER TABLE `provider`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT для таблицы `provider_prefix`
--
ALTER TABLE `provider_prefix`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT для таблицы `region`
--
ALTER TABLE `region`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT для таблицы `sms`
--
ALTER TABLE `sms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=784;

--
-- AUTO_INCREMENT для таблицы `tariff`
--
ALTER TABLE `tariff`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT для таблицы `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT для таблицы `user_priv`
--
ALTER TABLE `user_priv`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5202;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

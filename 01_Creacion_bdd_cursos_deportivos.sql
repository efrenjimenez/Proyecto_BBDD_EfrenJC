/***********************************
   Base de datos cursos deportivos
************************************/
--Para activar la salida por pantalla
SET SERVEROUTPUT ON;

--Borrar todas las tablas en orden inverso al de creación para no tener problemas con las claves foráneas:
DROP TABLE pago;
DROP TABLE inscripcion;
DROP TABLE curso;
DROP TABLE pista_deportiva;
DROP TABLE instalacion;
DROP TABLE usuario;
DROP TABLE auditoria_pagos;

/****************************************
 Requisito 01, registro de instalaciones 
*****************************************/
CREATE TABLE Instalacion
--La clave primaria es el código de la instalación, y el nombre es necesario para dar de alta una instalación.
--El código de instalación se creará con 3 siglas que hagan referencia al nombre de la instalación,
--así será más facil indetificarlas que con un número.
--Por ejemplo Pabellón Antonio García sería 'PAG'
(
    Cod_instalacion VARCHAR2(3) CONSTRAINT INS_DOC_PK PRIMARY KEY,
    Nombre_inst VARCHAR2(20) CONSTRAINT INS_NOM_NN NOT NULL,
    Direccion VARCHAR2(30),
    Telefono NUMBER(9)
);

/********************************************
 Requisito 02, registro de pistas deportivas
*********************************************/
CREATE TABLE Pista_deportiva
/*La clave primaria está compuesta por Cod_instalación (que a su vez es clave foranea) y Nombre_pista,
ya que considero que la entidad Pista_deportiva tiene una debilidad por indentificación con la instalación deportiva.
Ya que si no existiese esa instalación deportiva, no existirían las pistas que en ella se encuentran.
Por ejemplo si en la instalación 'PAG' hay dos pistas de baloncesto, las nombraríamos Baloncesto_1 y Baloncesto_2, y la clave primaria de
cada una de ellas sería PAG-Baloncesto_1 y PAG-Baloncesto_2.*/
(
    Cod_instalacion VARCHAR2(3) CONSTRAINT PIS_COD_FK REFERENCES instalacion,
    Nombre_pista VARCHAR2(15) CONSTRAINT PIS_NOM_NN NOT NULL,
    Aforo NUMBER(2),
    Iluminacion CHAR(2) CHECK (UPPER(Iluminacion) IN ('SI', 'NO')),
    Tipo VARCHAR2(15) DEFAULT 'DESCUBIERTA',
    CONSTRAINT PIS_COD_PK PRIMARY KEY (Cod_instalacion, Nombre_pista),
	CONSTRAINT PIS_TIP__CK CHECK (UPPER(Tipo) IN('CUBIERTA','DESCUBIERTA'))
);

/************************************
  Requisito 03, registro de cursos
*************************************/
CREATE TABLE Curso
/*El nombre del curso es la clave primaria, y se nombrará por ejemplo con la modalidad,
la instalación y las pista, las iniciales de los días, y la hora de inicio. Por ejemplo "Tenis L-X 19:00".
Los cursos sólo tendrán lugar de lunes a viernes, por eso la columna días tiene la restricción 
para comprobar que sólo se introducen esos días.
(Cod_instalacion, Nombre_pista) son juntas una clave foranea, ya que son la clave primaria de la 
tabla pista_deportiva que identifica de la pista donde se realiza el curso
Además incluye una restricción para que la hora de inicio del curso no pueda ser inferior a la hora de finalización*/
(
    Cod_curso VARCHAR2(10),
    Nombre VARCHAR2(30) CONSTRAINT CUR_NOM_UK UNIQUE,
    Cod_instalacion VARCHAR2(3),
    Nombre_pista VARCHAR2(15),
    Plazas NUMBER(2),
    Dias VARCHAR2(15) CONSTRAINT CUR_DIA_CK CHECK (UPPER(Dias) IN('LUNES-MIERCOLES','MARTES-JUEVES')),
    Hora_ini TIMESTAMP,
    Hora_fin TIMESTAMP,
    CONSTRAINT CUR_NOM_PK PRIMARY KEY (Cod_curso),
    CONSTRAINT CUR_COD_FK FOREIGN KEY(Cod_instalacion, Nombre_pista) REFERENCES pista_deportiva,
    CONSTRAINT CUR_HOR_CK CHECK (Hora_ini < Hora_fin)
);

/*************************************
  Requisito 04, registro de usuarios
**************************************/
CREATE TABLE Usuario
--La clave primaria es el código de usuario, pero Dni es único para que no se duplique un usuario en la base de datos.
--Tanto Dni, como Nombre y Apellidos no pueden estar vacios, para que al menos se introduzcan esos datos al crear al usuario.
(
    Cod_usuario NUMBER(6) CONSTRAINT USU_COD_PK PRIMARY KEY,
    Dni NUMBER(10) CONSTRAINT USUS_DNI_NN NOT NULL CONSTRAINT USU_DNI_UK UNIQUE,
    Nombre VARCHAR2(20) CONSTRAINT USU_NOM_NN NOT NULL,
    Apellidos VARCHAR2(30) CONSTRAINT USU_APE_NN NOT NULL,
    Fecha_nac DATE,
    Direccion VARCHAR2(30),
    Telefono VARCHAR2(12),
	Email VARCHAR2(40)
);

/******************************************
  Requisito 05, registro de inscripciones
*******************************************/
CREATE TABLE Inscripcion
/* La tabla "Inscripciones" resulta de la relación N:M entre usuario y Cursos, de ahí que la clave primaria sea: Cod_usuario y Nombre_curso.
Después se registra la fecha de alta del usuario en ese curso, y la de baja si se produjese
Por defecto la fecha de alta tomará la fecha actual*/
(
    Cod_usuario NUMBER(6) CONSTRAINT INS_COD_FK REFERENCES usuario,
    Cod_curso VARCHAR2(10) CONSTRAINT INS_NOM_FK REFERENCES curso,
    Fecha_alta TIMESTAMP DEFAULT LOCALTIMESTAMP,
    Fecha_baja DATE,
    Descuento VARCHAR2(2) DEFAULT 'NO' CONSTRAINT PAG_DES_CK CHECK (UPPER(Descuento) IN('SI', 'NO')),
    CONSTRAINT INS_COD_PK PRIMARY KEY (Cod_usuario, Cod_curso) 
);

/**********************************
  Requisito 06, registro de pagos
***********************************/
CREATE TABLE Pago
/*La tablo pago registará los pagos de cada usuario en cada uno de los cursos que esté inscrito.
Los registros de esta tabla se introducirán automáticamente los días 1 de cada mes 
con cada uno de los usuarios inscritos, y que no estén dados de baja.
Tendrá como clave primaria el codigo de usuario, el nombre del curso y la fecha del recibo.
Por defecto indicará el mes obteniéndolo de la fecha, y el estado como pendiente.
*/
(
    Cod_usuario NUMBER(6),
    Cod_curso VARCHAR2(15),
    Fecha_recibo DATE,
    Mes VARCHAR2(10) DEFAULT TO_CHAR(SYSDATE, 'MONTH') CONSTRAINT PAG_MES_CK CHECK (UPPER(mes) IN('ENERO', 'FEBRERO', 'MARZO', 
        'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE')),
    Importe NUMBER(6,2),
    Estado VARCHAR2(9) DEFAULT 'PENDIENTE' CONSTRAINT PAG_EST_CK CHECK (UPPER(estado) IN('PAGADO', 'PENDIENTE')),
    Fecha_pago DATE,
    CONSTRAINT PAG_COD_PK PRIMARY KEY (cod_usuario, cod_curso, mes),
    CONSTRAINT PAG_CNF_FK FOREIGN KEY (cod_usuario, cod_curso) REFERENCES Inscripcion
);

CREATE TABLE Auditoria_pagos
(
    Cod_usuario NUMBER(6),
    Cod_curso VARCHAR2(15),    
    Mes VARCHAR2(10),
    Estado_old VARCHAR2(9),
    Estado_new VARCHAR(9),
    Fecha DATE,
    Usuario_BD VARCHAR2(20)
);
    
/************************
    INSERCCIÓN DE DATOS
*************************/

INSERT INTO instalacion VALUES ('POL', 'Polideportivo', 'C/Pablo Neruda, s/n', 955442266);
INSERT INTO instalacion VALUES ('PAB', 'Pabellón', 'C/Pablo Picasso, s/n', 955664422);

INSERT INTO pista_deportiva VALUES ('POL', 'Tenis-01', 8, 'SI', DEFAULT);
INSERT INTO pista_deportiva VALUES ('POL', 'Tenis-02', 8, 'SI', 'Descubierta');
INSERT INTO pista_deportiva VALUES ('POL', 'Padel-01', 6, 'SI', 'Descubierta');
INSERT INTO pista_deportiva VALUES ('POL', 'Padel-02', 6, 'SI', 'Descubierta');
INSERT INTO pista_deportiva VALUES ('PAB', 'Tenis-01', 8, 'SI', 'Cubierta');
INSERT INTO pista_deportiva VALUES ('PAB', 'Padel-01', 6, 'SI', 'Cubierta');
INSERT INTO pista_deportiva VALUES ('PAB', 'Padel-02', 6, 'SI', 'Cubierta');

INSERT INTO curso VALUES ('TEN01', 'Tenis POL01 L-X 19:00', 'POL', 'Tenis-01', 6, 'Lunes-Miercoles', '01/01/01 19:00', '01/01/01 20:00');
INSERT INTO curso VALUES ('TEN02', 'Tenis POL02 L-X 19:00', 'POL', 'Tenis-02', 6, 'Lunes-Miercoles', '01/01/01 19:00', '01/01/01 20:00');
INSERT INTO curso VALUES ('TEN03', 'Tenis POL01 M-J 20:00', 'POL', 'Tenis-01', 6, 'Martes-Jueves', '01/01/01 20:00', '01/01/01 21:00');
INSERT INTO curso VALUES ('TEN04', 'Tenis POL02 M-J 20:00', 'POL', 'Tenis-02', 6, 'Martes-Jueves', '01/01/01 20:00', '01/01/01 21:00');
INSERT INTO curso VALUES ('TEN05', 'Tenis PAB01 L-X 19:00', 'PAB', 'Tenis-01', 6, 'Lunes-Miercoles', '01/01/01 19:00', '01/01/01 20:00');
INSERT INTO curso VALUES ('TEN06', 'Tenis PAB01 L-X 20:00', 'PAB', 'Tenis-01', 6, 'Lunes-Miercoles', '01/01/01 20:00', '01/01/01 21:00');
INSERT INTO curso VALUES ('PAD01', 'Padel POL01 L-X 19:00', 'POL', 'Padel-01', 4, 'Lunes-Miercoles', '01/01/01 20:00', '01/01/01 21:00');
INSERT INTO curso VALUES ('PAD02', 'Padel POL02 L-X 19:00', 'POL', 'Padel-02', 4, 'Lunes-Miercoles', '01/01/01 20:00', '01/01/01 21:00');
INSERT INTO curso VALUES ('PAD03', 'Padel PAB01 M-J 19:00', 'PAB', 'Padel-01', 4, 'Martes-Jueves', '01/01/01 19:00', '01/01/01 20:00');
INSERT INTO curso VALUES ('PAD04', 'Padel PAB02 M-J 19:00', 'PAB', 'Padel-02', 4, 'Martes-Jueves', '01/01/01 19:00', '01/01/01 20:00');

INSERT INTO usuario VALUES (1, '7908602770', 'Therine', 'Eagle', '24/09/1997', '74648 Londonderry Road', '475-233-0825', 'teagle0@symantec.com');
INSERT INTO usuario VALUES (2, '3089114550', 'Malachi', 'Grestie', '08/06/1988', '31 Artisan Circle', '971-803-8742', 'mgrestie1@typepad.com');
INSERT INTO usuario VALUES (3, '3983696554', 'Colette', 'Bemment', '19/12/1993', '3 Helena Circle', '723-408-1034', 'cbemment2@hc360.com');
INSERT INTO usuario VALUES (4, '6107242503', 'Antonina', 'Audry', '04/12/1996', '328 Oak Valley Road', '295-732-7185', 'aaudry3@cocolog-nifty.com');
INSERT INTO usuario VALUES (5, '8735920637', 'Talbot', 'Wemyss', '18/07/1981', '871 La Follette Junction', '242-401-7839', 'twemyss4@bing.com');
INSERT INTO usuario VALUES (6, '4951690837', 'Jessie', 'Gabits', '16/06/1983', '3 2nd Plaza', '170-968-0560', 'jgabits5@wufoo.com');
INSERT INTO usuario VALUES (7, '9188235920', 'Gerald', 'Freshwater', '26/04/1982', '07712 Spenser Park', '497-748-7178', 'gfreshwater6@chron.com');
INSERT INTO usuario VALUES (8, '3343749273', 'Elliott', 'McClarence', '05/11/1987', '4 Jenna Lane', '812-171-9273', 'emcclarence7@statcounter.com');
INSERT INTO usuario VALUES (9, '5736772493', 'Kipp', 'Everitt', '16/11/1987', '58024 Rusk Point', '499-123-6535', 'keveritt8@networkadvertising.org');
INSERT INTO usuario VALUES (10, '1983473642', 'Emmett', 'Dennerley', '11/02/1990', '59498 Mockingbird Hill', '957-212-4232', 'edennerley9@mashable.com');
INSERT INTO usuario VALUES (11, '5186835668', 'Ulrikaumeko', 'Mulles', '18/05/1992', '1 Canary Road', '491-869-9220', 'umullesa@sciencedirect.com');
INSERT INTO usuario VALUES (12, '3274796328', 'Flora', 'Doumer', '15/04/1996', '6345 Graceland Terrace', '526-151-7881', 'fdoumerb@51.la');
INSERT INTO usuario VALUES (13, '5738155882', 'Lianna', 'Eisold', '15/05/1983', '1 Pine View Plaza', '172-568-9696', 'leisoldc@eventbrite.com');
INSERT INTO usuario VALUES (14, '8776116301', 'Shurlock', 'Middlehurst', '30/10/1982', '0092 Arkansas Junction', '180-938-4434', 'smiddlehurstd@1688.com');
INSERT INTO usuario VALUES (15, '3143744944', 'Josselyn', 'Shemmin', '08/06/1988', '366 Meadow Valley Street', '430-388-0404', 'jshemmine@webmd.com');
INSERT INTO usuario VALUES (16, '9136450626', 'Christina', 'Bulfoy', '11/07/1991', '5 Thierer Road', '774-729-0833', 'cbulfoyf@yale.edu');
INSERT INTO usuario VALUES (17, '0830916296', 'Barny', 'Lawton', '15/12/1998', '6 Oriole Place', '102-588-1160', 'blawtong@1und1.de');
INSERT INTO usuario VALUES (18, '9617784920', 'Noella', 'Eardley', '18/02/1998', '5 Florence Center', '522-291-2273', 'neardleyh@biblegateway.com');
INSERT INTO usuario VALUES (19, '0596915500', 'Rafael', 'Angelini', '11/11/1977', '670 Union Way', '975-522-5798', 'rangelinii@51.la');
INSERT INTO usuario VALUES (20, '6266165600', 'Alisha', 'Matthius', '03/10/1980', '94411 Rigney Center', '205-562-2736', 'amatthiusj@ehow.com');
INSERT INTO usuario VALUES (21, '2596110075', 'Em', 'McIan', '06/10/1998', '08 Laurel Place', '478-700-4784', 'emciank@who.int');
INSERT INTO usuario VALUES (22, '5798947912', 'Debbi', 'Cullinan', '17/06/1995', '5800 Hallows Road', '540-953-9260', 'dcullinanl@psu.edu');
INSERT INTO usuario VALUES (23, '9649727337', 'Keslie', 'Bullion', '14/01/1993', '4 Schlimgen Drive', '360-222-3966', 'kbullionm@census.gov');
INSERT INTO usuario VALUES (24, '0793195276', 'Alikee', 'Benninger', '29/06/1982', '57 Vahlen Way', '837-711-5949', 'abenningern@wufoo.com');
INSERT INTO usuario VALUES (25, '0373387776', 'Marcelle', 'Fauning', '14/09/1999', '48 5th Park', '153-925-8081', 'mfauningo@marriott.com');
INSERT INTO usuario VALUES (26, '9967198796', 'Clarinda', 'Bread', '16/02/1978', '54 Mifflin Place', '432-207-8300', 'cbreadp@home.pl');
INSERT INTO usuario VALUES (27, '1988121388', 'Amalia', 'Dace', '23/04/1989', '492 Prentice Trail', '944-252-3449', 'adaceq@ning.com');
INSERT INTO usuario VALUES (28, '9267695185', 'Emera', 'Costall', '18/07/1989', '5435 Erie Plaza', '961-191-6176', 'ecostallr@umich.edu');
INSERT INTO usuario VALUES (29, '4636746139', 'Cynthea', 'Klas', '21/08/1984', '840 Daystar Plaza', '180-929-9117', 'cklass@google.es');
INSERT INTO usuario VALUES (30, '8197585989', 'Christin', 'Hookes', '13/02/1998', '64639 Hoard Parkway', '477-275-2474', 'chookest@furl.net');
INSERT INTO usuario VALUES (31, '5944132787', 'Claudia', 'Champneys', '07/12/1979', '73720 Sauthoff Street', '600-367-6726', 'cchampneysu@twitpic.com');
INSERT INTO usuario VALUES (32, '8033654759', 'Miriam', 'Vannet', '17/06/1992', '45168 Nobel Crossing', '141-541-6051', 'mvannetv@purevolume.com');
INSERT INTO usuario VALUES (33, '6616066045', 'Marja', 'Somerset', '14/02/1976', '714 Aberg Hill', '281-685-3043', 'msomersetw@nps.gov');
INSERT INTO usuario VALUES (34, '1336349751', 'Ginger', 'Keddle', '07/08/1987', '91711 Summit Avenue', '938-428-4580', 'gkeddlex@globo.com');
INSERT INTO usuario VALUES (35, '2233729137', 'Lesli', 'Godfree', '27/08/1994', '245 Ohio Road', '206-896-5376', 'lgodfreey@webs.com');
INSERT INTO usuario VALUES (36, '2361007215', 'Kacie', 'Giblin', '14/07/1991', '4570 Del Sol Street', '590-275-1261', 'kgiblinz@diigo.com');
INSERT INTO usuario VALUES (37, '8073544962', 'Darcee', 'Bloschke', '13/06/1982', '5183 Corscot Drive', '823-664-7684', 'dbloschke10@wikimedia.org');
INSERT INTO usuario VALUES (38, '9112313815', 'Oona', 'Pasby', '21/05/1978', '3658 Emmet Circle', '231-247-4123', 'opasby11@odnoklassniki.ru');
INSERT INTO usuario VALUES (39, '8324188207', 'Jeffry', 'L''oiseau', '19/09/1996', '98 Main Crossing', '727-424-9145', 'jloiseau12@theguardian.com');
INSERT INTO usuario VALUES (40, '9079864595', 'Rockie', 'D''Aguanno', '10/10/1982', '45743 Mockingbird Trail', '703-399-9191', 'rdaguanno13@blinklist.com');
INSERT INTO usuario VALUES (41, '4485932737', 'Salomone', 'Stelljes', '12/12/1992', '4481 Paget Hill', '434-493-6447', 'sstelljes14@marketwatch.com');
INSERT INTO usuario VALUES (42, '6456850568', 'Bryant', 'Phuprate', '22/05/1985', '9 Surrey Parkway', '779-120-9595', 'bphuprate15@army.mil');
INSERT INTO usuario VALUES (43, '5364136558', 'Ardith', 'Soigne', '13/08/1988', '343 Surrey Way', '614-111-3216', 'asoigne16@goo.ne.jp');
INSERT INTO usuario VALUES (44, '1619455838', 'Sheffield', 'Tournay', '16/08/1986', '10014 Ronald Regan Parkway', '668-518-5255', 'stournay17@delicious.com');
INSERT INTO usuario VALUES (45, '8629576693', 'Joelle', 'Moralas', '11/01/1999', '67508 Buhler Hill', '229-564-1883', 'jmoralas18@reverbnation.com');
INSERT INTO usuario VALUES (46, '0574275134', 'Barbe', 'Rahl', '23/08/1979', '5 Maywood Circle', '669-108-3446', 'brahl19@cnet.com');
INSERT INTO usuario VALUES (47, '7567394146', 'Willis', 'Gudyer', '13/03/1988', '6 Esker Junction', '351-955-0105', 'wgudyer1a@china.com.cn');
INSERT INTO usuario VALUES (48, '2352636159', 'Lamar', 'Golsthorp', '17/03/2000', '82834 Merrick Way', '525-191-1195', 'lgolsthorp1b@chicagotribune.com');
INSERT INTO usuario VALUES (49, '1603199292', 'Fergus', 'Pharro', '23/09/1992', '9394 Milwaukee Plaza', '187-844-1408', 'fpharro1c@liveinternet.ru');
INSERT INTO usuario VALUES (50, '6476031902', 'Shermie', 'Duesbury', '05/07/1980', '5 Holmberg Hill', '898-735-5935', 'sduesbury1d@blinklist.com');
INSERT INTO usuario VALUES (51, '4674961785', 'Abel', 'McGirl', '18/05/1983', '45 Eagle Crest Road', '441-691-8158', 'amcgirl1e@msu.edu');

ALTER SESSION SET NLS_TIMESTAMP_FORMAT='DD/MM/YYYY HH24:MI:SS.FF6';

COMMIT;


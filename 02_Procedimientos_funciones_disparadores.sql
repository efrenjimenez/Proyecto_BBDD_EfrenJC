/*****************************
  Requisito 07, inscripciones
******************************/
/*Función para buscar un usuario por su dni. La función recibirá el dni como
parámetro y devolverá el código de usuario, o bien devolverá -1 si no lo encuentra.
*/
CREATE OR REPLACE FUNCTION buscar_usuario(dni_usuario NUMBER) RETURN NUMBER IS
    --Variable para guardar el código de usuario que obtendrá el cursor.
    v_codigo_usuario NUMBER;
BEGIN
    --Cursor implícito que me devuelve el codigo de usuario a partir de su dni
    SELECT u.cod_usuario INTO v_codigo_usuario FROM usuario u WHERE u.dni = dni_usuario;
    --Devuelve el código de usuario.
    RETURN v_codigo_usuario;
    EXCEPTION
        --Excepción en caso de que no encuentre el usuario
        WHEN no_data_found THEN
            -- Mostrará el siguiente mensaje:
            dbms_output.put_line('No se ha encontrado ningún usuario con dni: '||dni_usuario); 
            --Devuelve "-1"
            RETURN -1;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);
END;
/

/*Función para buscar un curso por su nombre. La función recibirá el dni como
parámetro y devolverá una cadena con el código de usuario, o bien devolverá 
'no_encontrado' si no lo encuentra.
*/
CREATE OR REPLACE FUNCTION buscar_curso(nombre_curso VARCHAR2) RETURN VARCHAR2 IS
    --Variable para guardar el código del curso que obtendrá el cursor.  
    v_codigo_curso VARCHAR2(5);
BEGIN
    --Cursor implícito que me devuelve el codigo del curso a partir del nombre de curso
    SELECT c.cod_curso INTO v_codigo_curso FROM curso c WHERE UPPER(c.nombre) = UPPER(nombre_curso);
    --Devuelve el código del curso.    
    RETURN v_codigo_curso;   
    EXCEPTION
        --Excepción en caso de que no encuentre el usuario    
        WHEN no_data_found THEN
            -- Mostrará el siguiente mensaje:        
            DBMS_OUTPUT.PUT_LINE('No se ha encontrado ningún curso con nombre: '||nombre_curso); 
            --Devuelve 'no_encontrado"
            RETURN 'no_encontrado';
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);            
END;
/

/*Con este procedimiento se realiza la inscripción de un usuario en un curso.
El procedimiento recibe como parametro el dni y el nombre del curso, e
inserta un nuevo resgistro en la tabla "inscripcion" con lo siguientes datos:
*Código del curso
*Código del usuario
*Fecha de alta
*Fecha de baja (null)
*/
CREATE OR REPLACE PROCEDURE inscribir_usuario(dni_usuario NUMBER, nombre_curso VARCHAR2) IS
    --Variable para guardar el código de usuario.
    v_usuario NUMBER;
    --Variable para guardar el código del curso.
    v_curso VARCHAR(13);
BEGIN
    --La función "buscar_usuario" devuelve el código de usuario o "0" si no lo encuentra.
    v_usuario := buscar_usuario(dni_usuario);
    --La función "buscar_curso" devuelve el código del curso o "no_encontrado" si no lo encuentra.
    v_curso := buscar_curso(nombre_curso);
    --Con esta condición se controla que haya encontrado al usuario y al curso.
    --Si los encuentra crea la inscripción.
    IF v_usuario >0 AND v_curso <> 'no_encontrado' THEN
        --Esta condición es sobre una función que devuelve el número de registros que tiene el usuario en la tabla "inscripcion"
        --Si tiene al menos 1 inscripción, se creará el registro de inscripción con descuento 'SI', 
        --para que se le aplique un 10% de descuento en el pago.
        IF inscripciones_usuario(v_usuario) > 0 THEN
            INSERT INTO inscripcion (cod_usuario, cod_curso, fecha_alta, fecha_baja, descuento) 
                VALUES (v_usuario, v_curso, LOCALTIMESTAMP, null, 'SI'); 
        --Si no tiene ninguna otra inscripción con anterioridad, se creará el registro de inscripción con descuento 'NO'.           
        ELSE
            INSERT INTO inscripcion (cod_usuario, cod_curso, fecha_alta, fecha_baja, descuento) 
                VALUES (v_usuario, v_curso, LOCALTIMESTAMP, null, 'NO');
        END IF;
        --Tras insertar el registro en "inscripcion" mostrará el mensaje:
        DBMS_OUTPUT.PUT_LINE('Inscripción realizada.');
    --Y si no encuentra el usuario o el curso no realizará la inscripción y mostrará el siguiente mensaje.
    ELSE
        DBMS_OUTPUT.PUT_LINE('Inscripción no realizada.');
    END IF;
    COMMIT;
    EXCEPTION
        --Esta excepción controla que no haya un registro con el mismo usuario y mismo curso.
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('El usuario ya está inscrito en el curso');
        --Esta excepción mostraría mensaje de error para cualquier otra excepción.
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);
END;
/

--Este disparador sólo permitirá realizar inscripciones del día 1 al 15 de cada mes.
CREATE OR REPLACE TRIGGER fecha_limite_inscripcion
    --Antes de realizar el INSERT en la tabla isncripcion
    BEFORE INSERT ON inscripcion
BEGIN
    --Si el día del mes es mayor que 15 lanza la excepción y corta el flujo
    IF EXTRACT(DAY FROM SYSDATE) > 15 THEN
        RAISE_APPLICATION_ERROR (-20001,'No es posible realizar una inscripción después del día 15 del mes.');
    END IF;
END;
/

--Para deshabilitar el disparador y poder hacer pruebas.
    ALTER TRIGGER fecha_limite_inscripcion DISABLE;
--Para habilitar el disparador.
    --ALTER TRIGGER fecha_limite_inscripcion ENABLE;


/********************************
  Requisito 08, pago y descuento 
*********************************/
/*Cada vez que se realice un inscripción automáticamente se creará un registro en la tabla pago con lo datos
correspondientes. En caso de que el usuario esté ya inscrito al menos en un curso, se aplicará un descuento 
en el pago de la inscripción.
*/

--Disparador que ejecutará el procedimiento "generar_pago_inscripcion" cada vez que se realize una inscripción
CREATE OR REPLACE TRIGGER pago_inscripcion
    AFTER INSERT ON inscripcion
BEGIN
    generar_pago_inscripcion;
END;
/

--Procedimiento lanzado por el trigger "pago_inscripcion" que generará un registro en la tabla "pago"
--con los datos de la última inscripción realizada.
CREATE OR REPLACE PROCEDURE generar_pago_inscripcion IS
    --Cursor que obtendrá el último registro de la tabla inscripcion
    c_ultima_inscrip inscripcion%ROWTYPE;
    --Variable para guardar el codigo del usuario
    v_cod_usuario NUMBER;
    --Variable para guardar el código del curso
    v_cod_curso VARCHAR2(10);
    --Variable para guardar la fecha de alta
    v_fecha_alta TIMESTAMP;
BEGIN
    --Obtenemos la última fila insertada en la tabla "inscripción" ordenándolas por fecha de alta y la cargamos en el cursor.
    SELECT cod_usuario, cod_curso, fecha_alta, fecha_baja, descuento INTO c_ultima_inscrip
        FROM (SELECT i.cod_usuario, i.cod_curso, i.fecha_alta, i.fecha_baja, descuento
            FROM inscripcion i 
            ORDER BY i.fecha_alta DESC) 
        WHERE ROWNUM = 1;
    --Guardamos el valor del código de usuario obtenido por el cursor en la variable
    v_cod_usuario := c_ultima_inscrip.cod_usuario;
    --Guardamos el valor del código del curso obtenido por el cursor en la variable
    v_cod_curso := c_ultima_inscrip.cod_curso;
    --Guardamos el valor de la fecha de inscripción obtenida por el cursor en la variable    
    v_fecha_alta := c_ultima_inscrip.fecha_alta;
    --Esta condición es sobre la columna "Descuento" de la tabla inscripción
    
    --Si "Descuento" es igual a "SI", se insertará un registro en "pago" con un 10% de descuento en el importe.   
    IF c_ultima_inscrip.descuento = 'SI' THEN
        INSERT INTO pago (cod_usuario, cod_curso, fecha_recibo, mes, importe, estado, fecha_pago)
            VALUES (v_cod_usuario, v_cod_curso, v_fecha_alta, TRIM(TO_CHAR(v_fecha_alta, 'MONTH')), (28*0.9), DEFAULT, null);   
    --Si no, el pago se registrará con importe igual a 28.
    ELSE
        INSERT INTO pago (cod_usuario, cod_curso, fecha_recibo, mes, importe, estado, fecha_pago)
            VALUES (v_cod_usuario, v_cod_curso, v_fecha_alta, TRIM(TO_CHAR(v_fecha_alta, 'MONTH')), 28, DEFAULT, null);
    END IF;
    --Tras insertar el registro en "pago" se muestra el siguiente mensaje;
    DBMS_OUTPUT.PUT_LINE('Recibo generado correctamente'); 
    EXCEPTION
        --Esta excepción controla que no haya un registro con el mismo usuario, mismo curso y mismo mes.
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('El recibo de pago ya existe');
        --Esta excepción mostraría mensaje de error para cualquier otra excepción.
        WHEN OTHERS THEN
            --DBMS_OUTPUT.PUT_LINE('Se ha producido un error al crear el pago');
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);           
END;
/

--Función que devuelve el número de inscripciones que tiene un usuario dado su códdigo de usuario:
CREATE OR REPLACE FUNCTION inscripciones_usuario(p_cod_usuario NUMBER) 
RETURN NUMBER IS
    --Variable para guardar el número de inscripción del usuario
    v_num_inscripciones NUMBER;
BEGIN
    --Cursor implícito que obtendrá el número de inscripciones que tiene el usuario.
    SELECT COUNT(i.cod_usuario) INTO v_num_inscripciones FROM inscripcion i WHERE i.cod_usuario = p_cod_usuario;
    --Devuelve el número de inscripciones del usuario
    RETURN v_num_inscripciones;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);    
END;
/

/********************************
   Requisito 09, pagos mensuales
*********************************/
/*Con este procedimiento se generarán los nuevos registros de pago para todas los usuarios que estén inscritos.
Controlará que el usuario no esté dado de baja.
*/
CREATE OR REPLACE PROCEDURE generar_pagos_mensuales IS
    --Cursor que obtendrá el código de usuario, el código del curso y el descuento de cada una de las inscripciones sin fecha de baja
    CURSOR c_inscripciones IS
        SELECT i.cod_usuario AS "COD_USU", i.cod_curso AS "COD_CUR", i.descuento AS "DESCU"
            FROM inscripcion i WHERE fecha_baja IS NULL;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.                
    r_inscripciones c_inscripciones%ROWTYPE;
    --Variable para guardar el número de recibos encontrados.
    v_encontrados NUMBER;
    --Variable para guardar el número de recibos generados
    v_generados NUMBER;
BEGIN
    --Inicializamos las dos variables de recuento a 0
    v_encontrados := 0;
    v_generados := 0;
    --Abrimos el cursor que obtendrá cada una de las inscripciones
    OPEN c_inscripciones;
        LOOP
            FETCH c_inscripciones INTO r_inscripciones;
            EXIT WHEN c_inscripciones%NOTFOUND;
            --Para cada inscripción intentamos actualizar su correspondiente pago
            UPDATE pago SET mes = TRIM(TO_CHAR(SYSDATE, 'MONTH')) 
                WHERE cod_usuario = r_inscripciones.cod_usu 
                    AND cod_curso = r_inscripciones.cod_cur
                    AND mes = TRIM(TO_CHAR(SYSDATE, 'MONTH'));
            --Si el pago ya existe, se suma 1 a la variable encontrados
            IF SQL%FOUND = TRUE THEN
            v_encontrados := v_encontrados +1;
            --Si no existe lo generará teniendo en cuenta el descuento
            --Esta condición es sobre la columna "Descuento" de la tabla inscripción
            --Si "Descuento" es igual a "SI", se le aplicará un 10% de descuento en el importe del pago.   
            ELSIF r_inscripciones.descu = 'SI' THEN
                INSERT INTO pago (cod_usuario, cod_curso, fecha_recibo, mes, importe, estado, fecha_pago)
                    VALUES (r_inscripciones.cod_usu, r_inscripciones.cod_cur, SYSDATE, TRIM(TO_CHAR(SYSDATE, 'MONTH')), (28*0.9), DEFAULT, null);   
            --Si no, si "descuento" tiene el valor "NO", el pago se registrará con valor 28.
            ELSE
                INSERT INTO pago (cod_usuario, cod_curso, fecha_recibo, mes, importe, estado, fecha_pago)
                    VALUES (r_inscripciones.cod_usu, r_inscripciones.cod_cur, SYSDATE, TRIM(TO_CHAR(SYSDATE, 'MONTH')), 28, DEFAULT, null);
            v_generados := v_generados +1;                  
            END IF;
        END LOOP;
        --Mostramos un mensaje con el número de registro de pago que se han generado y el mes
        DBMS_OUTPUT.PUT_LINE('Se han encontrado '||v_encontrados||' recibos de pago para el mes de ' ||TRIM(TO_CHAR(SYSDATE, 'MONTH')));
        DBMS_OUTPUT.PUT_LINE('Se han generado '||v_generados||' nuevos recibos de pago para el mes de ' ||TRIM(TO_CHAR(SYSDATE, 'MONTH')));
        DBMS_OUTPUT.PUT_LINE('Suman un total de '||(v_generados + v_encontrados)||' recibos de pago para el mes de ' ||TRIM(TO_CHAR(SYSDATE, 'MONTH')));
    CLOSE c_inscripciones;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Se ha producido un error al crear el pago');
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);    
END;
/


/**********************************
  Requisito 10, actualización pago
***********************************/
/*El siguiente procedimiento recibirá como parámetro el dni de un usuario y
el nombre del curso, y el mes. Y actualizará la columna "ESTADO" del registro 
correspondiente de la tabla pago a "PAGADO".
*/
CREATE OR REPLACE PROCEDURE actualizar_pago(p_cod_usuario NUMBER, p_cod_curso VARCHAR2, p_mes VARCHAR2) IS

    error_al_actualizar EXCEPTION;
    r_pago pago%ROWTYPE;
BEGIN
    SELECT p.cod_usuario, p.cod_curso, p.fecha_recibo, p.mes, p.importe, p.estado, p.fecha_pago
        INTO r_pago
        FROM pago p 
        WHERE p.cod_usuario=p_cod_usuario
            AND p.cod_curso=p_cod_curso AND p.mes=p_mes;
    IF r_pago.estado = 'PAGADO' THEN
        RAISE error_al_actualizar;
    ELSE
    UPDATE pago p SET p.estado = 'PAGADO', p.fecha_pago=SYSDATE WHERE p.cod_usuario=p_cod_usuario
        AND p.cod_curso=p_cod_curso AND p.mes=p_mes;
    DBMS_OUTPUT.PUT_LINE('Pago Actualizado');
    END IF;
    EXCEPTION
        --Excepción en caso de que no exista el registro de pago.
        WHEN no_data_found THEN
            DBMS_OUTPUT.PUT_LINE('El registro de pago no existe.');
        --Excepción que controla que el estado del pago no esté ya como 'PAGADO'
        WHEN error_al_actualizar THEN
            DBMS_OUTPUT.PUT_LINE('El registro ya consta como PAGADO.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);        
END;
/

/**********************************
  Requisito 11, auditoria pagos
***********************************/
/*Con el siguiente disparador se llevará un control de las actulizaciones de los pagos.
Cada vez que se realice una actualización de pago, se registrará los datos del mismo,
así como el usuario de la base de datos que lo realizó.
*/
CREATE OR REPLACE TRIGGER auditoria_pagos
    BEFORE UPDATE OF estado ON pago
    FOR EACH ROW
BEGIN
--Antes de cambiar el estado del pago se insertan en la tabla auditoria_pagos
    INSERT INTO auditoria_pagos VALUES(
            --Los datos existentes del pago
            :OLD.cod_usuario,
            :OLD.cod_curso,
            :OLD.mes,
            :OLD.estado,
            --El nuevo estado del pago
            :NEW.estado,
            --La fecha y la hora del UPDATE
            SYSDATE,
            --El usuario que realizó el UPDATE
            USER);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);    
END auditoria_pagos;
/


/*******************************************
  Requisito 12, informe ocupación de cursos 
********************************************/
/*Con el siguiente procedimiento se generará un listado por curso con el número de plazas
ofertadas, plazas ocupadas y plazas libres.
*/
CREATE OR REPLACE PROCEDURE informe_ocupacion IS
    --Cursor que obtendrá los datos de las plazas de cada curso, incluso de los que no tengan ninguna inscripción
    CURSOR c_ocupacion IS
        SELECT c.cod_curso, c.nombre, c.plazas, COUNT(i.cod_curso) AS "PLAZAS_OCUPADAS", 
            (c.plazas-COUNT(i.cod_curso)) AS "PLAZAS_LIBRES"
            FROM curso c, inscripcion i
            WHERE c.cod_curso = i.cod_curso (+)
            GROUP BY c.cod_curso, c.nombre, c.plazas
            ORDER BY c.nombre;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.
    r_ocupacion c_ocupacion%ROWTYPE;
BEGIN
    --Abrimos el cursor que nos dará la información de cada curso
    OPEN c_ocupacion;
    DBMS_OUTPUT.PUT_LINE('*INFORME DE OCUPACIÓN DE CURSOS                           '||'Generado el '||SYSDATE);
    DBMS_OUTPUT.PUT_LINE(' ');    
    DBMS_OUTPUT.PUT_LINE(' CURSO                    | Plazas | Ocupadas | Libres |');    
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------------');
    --En cada una de las iteraciones del LOOP mostraremos los datos de cada uno de los cursos.
    LOOP
        --Recuperamos los datos del cursor, y los insertamos en la variable de registro.
        FETCH c_ocupacion INTO r_ocupacion;
        --Saldrá del bucle cunado el cursor no encuentre más registros
        EXIT WHEN c_ocupacion%NOTFOUND;
        --Mostramos el nombre del curso, las plazas ofertadas, las ocupadas y las libres
        DBMS_OUTPUT.PUT_LINE(' '||r_ocupacion.nombre||'    |   '||
            r_ocupacion.plazas||'    |    '||
            r_ocupacion.plazas_ocupadas||'     |   '||
            r_ocupacion.plazas_libres||'    |');
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------------');            
    END LOOP;
    CLOSE c_ocupacion;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);    
END;
/


/*******************************************
  Requisito 13, listado usuarios por curso 
********************************************/
/*Con el siguiente procedimiento se generará un listado por curso con los datos de cada
uno de los usuarios inscritos en el curso.
*/
CREATE OR REPLACE PROCEDURE inscripciones_cursos IS
    --Cursor que recorrerá las instalaciones
    CURSOR c_instalaciones IS
        SELECT i.cod_instalacion, i.nombre_inst
            FROM instalacion i
            ORDER BY i.cod_instalacion;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.
    r_instalaciones c_instalaciones%ROWTYPE;
    --Cursor que recorrerá las pistas
    CURSOR c_pistas(codigo_instalacion VARCHAR2) IS
        SELECT p.nombre_pista AS "NOMBRE_PIS", p.cod_instalacion AS "COD_INST"
            FROM pista_deportiva p
            WHERE p.cod_instalacion = codigo_instalacion
            ORDER BY p.nombre_pista;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.
    r_pistas c_pistas%ROWTYPE;    
    --Cursor que recorrerá todos los registros de la tabla curso.
    CURSOR c_cursos(codigo_inst VARCHAR2, nombre_pis VARCHAR2) IS
        SELECT c.cod_curso, c.nombre, c.cod_instalacion
            FROM curso c
            WHERE c.cod_instalacion = codigo_inst
                AND c.nombre_pista = nombre_pis
            ORDER BY c.cod_curso;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.            
    r_cursos c_cursos%ROWTYPE;
    --Cursor que obtendrá para cada curso los datos de cada uno de los usuarios inscritos.
    CURSOR c_inscripciones(codigo_curso VARCHAR2) IS
        SELECT u.cod_usuario, u.apellidos, u.nombre, u.telefono
            FROM  inscripcion i, usuario u
            WHERE i.cod_curso = codigo_curso
                AND i.cod_usuario = u.cod_usuario
            ORDER BY u.apellidos, u.nombre;
    --Variable para guardar las datos obtenidos por el cursor de cada registro de la consulta anterior.    
    r_inscripciones c_inscripciones%ROWTYPE;
BEGIN
    --Encabezado que indica el contenido y la fecha de genreación del informe
    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('*LISTADO DE USUARIOS POR CURSO                       '||'Generado el '||SYSDATE);
    --Abrimos el cursor que obtendrá las instalaciones
    OPEN c_instalaciones;
    --Con este bucle se muestra el nombre de cada una de las instalaciones.
    LOOP
        --Recuperamos los datos del cursor, y los insertamos en la variable de registro.    
        FETCH c_instalaciones INTO r_instalaciones;
        --Saldrá del bucle cuando el cursor no encuentre más registros        
        EXIT WHEN c_instalaciones%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('******************************************************************************');        
        DBMS_OUTPUT.PUT_LINE(' > Instalación: '||r_instalaciones.nombre_inst);
        DBMS_OUTPUT.PUT_LINE('******************************************************************************');         
        --Abrimos el cursor que obtendrá las pistas
        OPEN c_pistas(r_instalaciones.cod_instalacion);
        --Con este bucle se muestran todas las pistas de cada instalación
        LOOP
            --Recuperamos los datos del cursor, y los insertamos en la variable de registro.    
            FETCH c_pistas INTO r_pistas;
            --Saldrá del bucle cuando el cursor no encuentre más registros        
            EXIT WHEN c_pistas%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE(' ');
            DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('   >> Pista: '||r_instalaciones.cod_instalacion||' '||r_pistas.nombre_pis);
            DBMS_OUTPUT.PUT_LINE('   -------------------------------------------------------------------------');            
            --Abrimos el cursor que obtendrá los cursos
            OPEN c_cursos(r_pistas.cod_inst, r_pistas.nombre_pis);    
            --Con este bucle se muestra el nombre de cada uno de los cursos de la pista.
            LOOP
                --Recuperamos los datos del cursor, y los insertamos en la variable de registro.    
                FETCH c_cursos INTO r_cursos;
                --Saldrá del bucle cuando el cursor no encuentre más registros        
                EXIT WHEN c_cursos%NOTFOUND;
                DBMS_OUTPUT.PUT_LINE(' ');
                --DBMS_OUTPUT.PUT_LINE('      ......................................................................');
                DBMS_OUTPUT.PUT_LINE('      >>> Curso: '||r_cursos.nombre);
                DBMS_OUTPUT.PUT_LINE('      ......................................................................');
                --En caso de no encontrsar ningún curso inscrito en la pista mostrará el siguiente mensaje.                
                IF c_cursos%ROWCOUNT = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('      No hay cursos en esta pista');
                END IF;                
                --Abrimos el siguiente cursor, que nos dará las inscripciones de cada curso.
                OPEN c_inscripciones(r_cursos.cod_curso);
                    --El siguiente buclé mostrará los datos de cada uno de los usuarios inscritos en el curso.
                    LOOP
                        --Recuperamos los datos del cursor, y los insertamos en la variable de registro.                
                        FETCH c_inscripciones INTO r_inscripciones;
                        --Saldrá del bucle cuando el cursor no encuentre más registros 
                        EXIT WHEN c_inscripciones%NOTFOUND;
                        --Mostramos los datos de cada usuario isncrito en el curso
                        DBMS_OUTPUT.PUT_LINE('          * '||
                            r_inscripciones.apellidos||', '||
                            r_inscripciones.nombre||' | '||
                            'Cod: '||r_inscripciones.cod_usuario||' | '||
                            'Tlf: '||r_inscripciones.telefono);
                    END LOOP;
                    --En caso de no encontrsar ningún usuario inscrito en el curso mostrará el siguiente mensaje.
                    IF c_inscripciones%ROWCOUNT = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('          No hay usuarios inscritos');
                    END IF;
                CLOSE c_inscripciones;
            END LOOP;
            CLOSE c_cursos;
        END LOOP;
        CLOSE c_pistas;   
    END LOOP;       
    CLOSE c_instalaciones;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);     
END;
/


/*************************************
  Requisito 14, ficha de usuario
*************************************/
/*Con el siguiente procedimiento, dado el dni de un usuario se generará una ficha
con sus datos, los inscritos en los que está o ha estado inscrito, así como los
pagos pendientes si los tuviera.
*/
CREATE OR REPLACE PROCEDURE ficha_usuario(p_dni NUMBER) IS
    --Variable para guardar el código del usuario
    v_usuario NUMBER;
    --Variable de registro para guardar los datos del cursor implicito
    r_usuario usuario%ROWTYPE;
    --Cursor para obtener los inscripciones del usuario, recibe como parametro el código de usuario.
    CURSOR c_inscripciones(p_cod_usuario NUMBER) IS
        SELECT c.nombre, i.cod_curso, TO_CHAR(i.fecha_alta, 'DD/MM/YYYY') AS "ALTA", i.fecha_baja
            FROM inscripcion i, curso c
            WHERE i.cod_curso = c.cod_curso
                AND i.cod_usuario = p_cod_usuario; 
    r_inscripciones c_inscripciones%ROWTYPE;
    --Cursor para obtener los pagos pendientes del usuario, recibe como parametro el código de usuario.
    CURSOR c_pagos(p_cod_usuario NUMBER) IS
        SELECT p.cod_curso, p.fecha_recibo, p.mes, TRIM(TO_CHAR(p.importe, '999G99D00L')) AS "IMPORTE", p.estado
            FROM pago p
            WHERE p.cod_usuario = p_cod_usuario
                AND UPPER(p.estado) = 'PENDIENTE';
    r_pagos c_pagos%ROWTYPE; 
BEGIN
    --A la variable v_usuario se le da el valor del codigo de usuario mediante la función buscar_usuario.
    --Que a partir del dni devuelve el código de usuario.
    v_usuario := buscar_usuario(p_dni);
    
    --Cursor para obtener los datos del usuario:
    SELECT u.cod_usuario, u.dni, u.nombre, u.apellidos,  u.fecha_nac, 
         u.direccion, u.telefono, u.email
        INTO r_usuario
        FROM usuario u
        WHERE cod_usuario = v_usuario;
        --Mostramos los datos del usuario
        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('FICHA DE USUARIO: '||r_usuario.nombre||' '||r_usuario.apellidos||
            '                           Generado el: '||SYSDATE);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('  *COD. USUARIO: '||r_usuario.cod_usuario);
        DBMS_OUTPUT.PUT_LINE('  *NOMBRE: '||r_usuario.nombre);
        DBMS_OUTPUT.PUT_LINE('  *APELLIDOS: '||r_usuario.apellidos);
        DBMS_OUTPUT.PUT_LINE('  *DNI: '||r_usuario.dni);
        DBMS_OUTPUT.PUT_LINE('  *TELÉFONO: '||r_usuario.telefono);
        DBMS_OUTPUT.PUT_LINE('  *EMAIL: '||r_usuario.email);
        
    --Para mostrar las inscripciones del usuario. 
    --Abrimos el cursor que obtendrá los inscripciones del usuario
    OPEN c_inscripciones(v_usuario);
    DBMS_OUTPUT.PUT_LINE('  *INSCRIPCIONES:                   Alta       Baja');
    LOOP
        --Recuperamos los datos del cursor, y los insertamos en la variable de registro.         
        FETCH c_inscripciones INTO r_inscripciones;
        --Saldrá del bucle cuando el cursor no encuentre más registros 
        EXIT WHEN c_inscripciones%NOTFOUND;
        --Si el usuario no está dado de baja en el curso solo se mostrará la fecha de alta.
        IF r_inscripciones.fecha_baja = NULL THEN
        DBMS_OUTPUT.PUT_LINE('    -'||r_inscripciones.cod_curso||' '||r_inscripciones.nombre||' '||r_inscripciones.alta);
        --Si el usuario está dado de baja en el curso se muestra también la fecha de baja.
        ELSE
        DBMS_OUTPUT.PUT_LINE('    -'||r_inscripciones.cod_curso||' '||r_inscripciones.nombre||' '||r_inscripciones.alta||' '||r_inscripciones.fecha_baja);
        END IF;
    END LOOP;
    CLOSE c_inscripciones;
    
    --Abrimos el cursor para obtener las pagos pendientes del usuario:   
    OPEN c_pagos(v_usuario);
    DBMS_OUTPUT.PUT_LINE('  *PAGOS PENDIENTES:');
    LOOP
        --Recuperamos los datos del cursor, y los insertamos en la variable de registro. 
        FETCH c_pagos INTO r_pagos;
        --Saldrá del bucle cuando el cursor no encuentre más registros
        EXIT WHEN c_pagos%NOTFOUND;
            --Mostrarmos los registro de pago con estado "PENDIENTE" del ususario
            DBMS_OUTPUT.PUT_LINE('    -'||r_pagos.cod_curso||' Fecha_recibo:'||r_pagos.fecha_recibo||
                '  Mes:'||r_pagos.mes||'  Importe:'||r_pagos.importe||'  Estado:'||r_pagos.estado);
    END LOOP;
    --En caso de no encontrsar ningún usuario inscrito en el curso mostrará el siguiente mensaje.
    IF c_pagos%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('    -El usuario no tiene pagos pendientes');
    END IF;    
    CLOSE c_pagos;
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------');   
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);     
END;
/

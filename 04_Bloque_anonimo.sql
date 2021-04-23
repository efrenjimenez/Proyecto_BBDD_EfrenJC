/**********************
    Bloque anómino
***********************/

DECLARE
    v_opcion NUMBER;
BEGIN
    v_opcion := 1;
    CASE v_opcion
    --(1)Crear una inscripción y después generar el registro en pago.   
        WHEN 1 THEN inscribir_usuario(7908602770,'Padel PAB02 M-J 19:00');
    --(2)Control de la fecha de inscripción. (Previamente hay que habilitar el disparador "fecha_limite_inscripcion"
        WHEN 2 THEN inscribir_usuario(3089114550,'Padel PAB02 M-J 19:00');
    --(3)Generar todos los recibos de pago del mes.
        WHEN 3 THEN generar_pagos_mensuales;
    --(4)Actualizar el pago de una mensualidad.
        WHEN 4 THEN actualizar_pago(1,'TEN01','MARZO');
    --(5)Visualizar el informe de ocupación de cursos.
        WHEN 5 THEN informe_ocupacion;
    --(6)Mostrar usuarios inscritos por cursos:    
        WHEN 6 THEN inscripciones_cursos;   
    --(7)Mostrar ficha de usuario:
        WHEN 7 THEN ficha_usuario(7908602770);
    ELSE DBMS_OUTPUT.PUT_LINE('Opción no válida');
    END CASE;
    COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Ocurrió el error ' || SQLCODE ||' mensaje: ' || SQLERRM);        
END;
/

CLASS lsc_zsei_r_cds_plupload DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zsei_r_cds_plupload IMPLEMENTATION.

  METHOD save_modified.

    DATA(lo_wrapper) = NEW zsei_cl_vms_wrapper( ).

    " Cargas que en este grabado cambiaron su estado a 'P'
    LOOP AT update-plupload INTO DATA(ls_cab)
         WHERE %control-estado = if_abap_behv=>mk-on
           AND estado = 'P'.

      " Sus ítems (con VGUID, VIN y características del prelog)
      READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
        ENTITY plupload BY \_item
        FIELDS ( vguid vin caracteristicas )
        WITH VALUE #( ( uploaduuid = ls_cab-uploaduuid ) )
        RESULT DATA(items).

      LOOP AT items INTO DATA(item).

        " SMOD: VIN al vehículo
        lo_wrapper->set_vin( iv_vguid = item-vguid
                             iv_vin   = item-vin ).

        " ZCAR: "ZZENGINE=MTR001;ZZMODEL_YEAR=2026" → tabla de nombre/valor
        DATA lt_caract TYPE zsei_cl_vms_wrapper=>tt_caract.
        CLEAR lt_caract.
        SPLIT item-caracteristicas AT ';' INTO TABLE DATA(lt_pares).
        LOOP AT lt_pares INTO DATA(lv_par).
          SPLIT lv_par AT '=' INTO DATA(lv_nombre) DATA(lv_valor).
          APPEND VALUE #( nombre = lv_nombre valor = lv_valor ) TO lt_caract.
        ENDLOOP.

        lo_wrapper->set_caracteristicas( iv_vguid  = item-vguid
                                         it_caract = lt_caract ).
      ENDLOOP.

      " Asignación entrega ↔ lote (paso 10 de la spec)
      lo_wrapper->asignar_entrega( it_vguid   = VALUE #( FOR i IN items ( i-vguid ) )
                                   iv_entrega = ls_cab-entrega ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lcl_handler DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR plupload
        RESULT result,
      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR plupload RESULT result.

    METHODS ejecutar FOR MODIFY
      IMPORTING keys FOR ACTION plupload~ejecutar RESULT result.

    METHODS procesar FOR MODIFY
      IMPORTING keys FOR ACTION plupload~procesar RESULT result.

    METHODS setdatosoc FOR DETERMINE ON MODIFY
      IMPORTING keys FOR plupload~setdatosoc.

    METHODS setestadoinicial FOR DETERMINE ON MODIFY
      IMPORTING keys FOR plupload~setestadoinicial.

    METHODS validarconfig FOR VALIDATE ON SAVE
      IMPORTING keys FOR plupload~validarconfig.

    METHODS validardatos FOR VALIDATE ON SAVE
      IMPORTING keys FOR plupload~validardatos.

    METHODS validarmarca FOR VALIDATE ON SAVE
      IMPORTING keys FOR plupload~validarmarca.

    METHODS validarordencompra FOR VALIDATE ON SAVE
      IMPORTING keys FOR plupload~validarordencompra.
ENDCLASS.

CLASS lcl_handler IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
     ENTITY plupload
     FIELDS ( estado ) WITH CORRESPONDING #( keys )
     RESULT DATA(pluploads).

    result = VALUE #( FOR plupload IN pluploads
        ( %tky = plupload-%tky

          " Ejecutar: solo si ya está guardada (no draft) y no se procesó
          %action-ejecutar = COND #(
            WHEN plupload-%is_draft = if_abap_behv=>mk-on OR plupload-estado = 'P'
            THEN if_abap_behv=>fc-o-disabled
            ELSE if_abap_behv=>fc-o-enabled )

          " Procesar: solo si está guardada y el prelog salió todo verde
          %action-procesar = COND #(
            WHEN plupload-%is_draft = if_abap_behv=>mk-off AND plupload-estado = 'V'
            THEN if_abap_behv=>fc-o-enabled
            ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.

  METHOD ejecutar.

    DATA lt_crear  TYPE TABLE FOR CREATE zsei_r_cds_plupload\\plupload\_item.
    DATA lt_update TYPE TABLE FOR UPDATE zsei_r_cds_plupload\\plupload.
    DATA lt_vins   TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    CONSTANTS lc_status_ok TYPE c LENGTH 4 VALUE 'Z001'.   " status válido (MMSTA)
    DATA lt_usados TYPE SORTED TABLE OF sysuuid_x16 WITH UNIQUE KEY table_line.

    " 1. Leer las cargas
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      FIELDS ( ordencompra datosexcel proveedor orgcompra marca )
      WITH CORRESPONDING #( keys )
      RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).

      " 2. Borrar el prelog anterior (por si ejecutan dos veces)
      READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
        ENTITY plupload BY \_item
        FIELDS ( itemuuid )
        WITH VALUE #( ( %tky = plupload-%tky ) )
        RESULT DATA(items_viejos).

      IF items_viejos IS NOT INITIAL.
        MODIFY ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
          ENTITY plitem
          DELETE FROM VALUE #( FOR item IN items_viejos ( %tky = item-%tky ) ).
      ENDIF.

      " 3. Leer la configuración ordenada por correlativo
      SELECT correlativo, accion, dato
        FROM zsei_r_cds_packlist
        WHERE proveedor = @plupload-proveedor
          AND orgcompra = @plupload-orgcompra
          AND marca     = @plupload-marca
        ORDER BY correlativo
        INTO TABLE @DATA(lt_config).

      " 4. Partir el texto en filas (Windows usa CR+LF, lo normalizamos)
      DATA(lv_texto) = replace( val  = plupload-datosexcel
                                sub  = cl_abap_char_utilities=>cr_lf
                                with = cl_abap_char_utilities=>newline
                                occ  = 0 ).
      SPLIT lv_texto AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_filas).
      DELETE lt_filas WHERE table_line IS INITIAL.   " líneas vacías
      DELETE lt_filas INDEX 1.                        " fila 1 = encabezados

      " Preparamos la "caja" de ítems nuevos de esta carga
      APPEND VALUE #( %tky = plupload-%tky ) TO lt_crear ASSIGNING FIELD-SYMBOL(<ls_crear>).
      DATA ls_item LIKE LINE OF <ls_crear>-%target.
      DATA(lv_hay_error) = abap_false.
      CLEAR lt_vins.

      " BUSQUEDA 1 - Con la OC obtener los VGUIDs
      CLEAR lt_usados.

      " Vehículos de la OC con status válido + su color (búsquedas 1, 2 y 5 de la spec)
      SELECT veh~vmsvehicleuuid   AS vguid,
             veh~vmsvehiclebatch  AS lote,
             veh~material         AS material,
             zvlc~zzcolor_code     AS color
        FROM zsei_i_cds_veh_mock AS veh
        LEFT OUTER JOIN zsei_vlcvehicle AS zvlc
          ON zvlc~vguid = veh~vmsvehicleuuid
        WHERE veh~purchaseorder           = @plupload-ordencompra
          AND veh~vmsvehicleprimarystatus = @lc_status_ok
        ORDER BY veh~vmsvehiclebatch
        INTO TABLE @DATA(lt_candidatos).


      " 5. Recorrer cada fila del Excel
      LOOP AT lt_filas INTO DATA(lv_fila).
        DATA(lv_nro_fila) = sy-tabix + 1.     " +1 porque la fila 1 era el encabezado

        SPLIT lv_fila AT cl_abap_char_utilities=>horizontal_tab INTO TABLE DATA(lt_celdas).

        CLEAR ls_item.
        ls_item-%cid      = |FILA{ lv_nro_fila }|.
        ls_item-%is_draft = plupload-%is_draft.
        ls_item-fila      = lv_nro_fila.

        " 6. Cada correlativo = una columna. La acción dice qué hacer con ella
        LOOP AT lt_config INTO DATA(ls_cfg).
          DATA(lv_valor) = condense( VALUE string( lt_celdas[ sy-tabix ] OPTIONAL ) ).

          CASE ls_cfg-accion.
            WHEN 'BUSC'.
              CASE ls_cfg-dato.
                WHEN 'MATNR'.        ls_item-material = lv_valor.
                WHEN 'ZZCOLOR_CODE'. ls_item-color    = lv_valor.
              ENDCASE.
            WHEN 'SMOD'.
              ls_item-vin = lv_valor.
            WHEN 'ZCAR'.
              ls_item-caracteristicas = COND #(
                WHEN ls_item-caracteristicas IS INITIAL
                THEN |{ ls_cfg-dato }={ lv_valor }|
                ELSE |{ ls_item-caracteristicas };{ ls_cfg-dato }={ lv_valor }| ).
          ENDCASE.
        ENDLOOP.

        " 7. Revisiones simples por fila (la búsqueda de lote viene en la parte 2)
        IF ls_item-material IS INITIAL OR ls_item-vin IS INITIAL.
          ls_item-criticidad = 1.
          ls_item-mensaje    = 'Faltan datos obligatorios (material o VIN)'.
        ELSE.

          INSERT CONV string( ls_item-vin ) INTO TABLE lt_vins.
          IF sy-subrc <> 0.
            ls_item-criticidad = 1.
            ls_item-mensaje    = |VIN { ls_item-vin } repetido en el archivo|.
          ELSE.

            " VIN ya existe en VMS
            SELECT SINGLE @abap_true
              FROM zsei_i_cds_veh_mock
              WHERE vehicleidentificationnumber = @ls_item-vin
              INTO @DATA(lv_vin_existe).

            IF lv_vin_existe = abap_true.
              ls_item-criticidad = 1.
              ls_item-mensaje    = |VIN { ls_item-vin } ya existe en VMS|.
              CLEAR lv_vin_existe.

            ELSE.
              " Buscar el primer lote libre (búsqueda 3: material, búsqueda 4: color)
              LOOP AT lt_candidatos INTO DATA(ls_cand) WHERE material = ls_item-material.

                " Si el Excel trae color, tiene que coincidir
                IF ls_item-color IS NOT INITIAL AND ls_cand-color <> ls_item-color.
                  CONTINUE.
                ENDIF.

                " Si ese vehículo ya lo tomó otra fila, siguiente
                IF line_exists( lt_usados[ table_line = ls_cand-vguid ] ).
                  CONTINUE.
                ENDIF.

                " ¡Encontrado! Lo asignamos y lo marcamos como usado
                ls_item-lote  = ls_cand-lote.
                ls_item-vguid = ls_cand-vguid.
                INSERT ls_cand-vguid INTO TABLE lt_usados.
                EXIT.
              ENDLOOP.

              IF ls_item-lote IS INITIAL.
                ls_item-criticidad = 1.
                ls_item-mensaje    = 'Sin coincidencias'.
              ELSE.
                ls_item-criticidad = 3.
                ls_item-mensaje    = 'OK'.
              ENDIF.
            ENDIF.

          ENDIF.
        ENDIF.

        IF ls_item-criticidad = 1.
          lv_hay_error = abap_true.
        ENDIF.

        APPEND ls_item TO <ls_crear>-%target.
      ENDLOOP.

      " 8. Estado de la carga según el resultado
      APPEND VALUE #( %tky   = plupload-%tky
                      estado = COND #( WHEN lv_hay_error = abap_true THEN 'E' ELSE 'V' ) )
             TO lt_update.

    ENDLOOP.

    " 9. Grabar ítems nuevos y estado
    MODIFY ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
        CREATE BY \_item
        FIELDS ( fila material color vin lote vguid caracteristicas criticidad mensaje )
        WITH lt_crear
      ENTITY plupload
        UPDATE FIELDS ( estado )
        WITH lt_update.

    " 10. Devolver la carga actualizada para que Fiori refresque la pantalla
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    result = VALUE #( FOR res IN lt_resultado ( %tky = res-%tky %param = res ) ).

  ENDMETHOD.

  METHOD procesar.
    DATA lt_upd_cab  TYPE TABLE FOR UPDATE zsei_r_cds_plupload\\plupload.
    DATA lt_upd_item TYPE TABLE FOR UPDATE zsei_r_cds_plupload\\plitem.

    DATA(lo_wrapper) = NEW zsei_cl_vms_wrapper( ).   " Instancia clase wrapper tier2

    " 1. Leer las cargas
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      FIELDS ( estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(pluploads).

    " Solo se procesan las que salieron todo verde
    LOOP AT pluploads INTO DATA(plupload) WHERE estado = 'V'.

      " 2. Leer sus ítems
      READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
        ENTITY plupload BY \_item
        FIELDS ( vguid )
        WITH VALUE #( ( %tky = plupload-%tky ) )
        RESULT DATA(items).

      " 3. Acción colectiva Z130: una entrega para todos los vehículos
      DATA(lv_entrega) = lo_wrapper->crear_entrega( VALUE #( FOR i IN items ( i-vguid ) ) ).

      " 4. Mensaje final en cada ítem
      LOOP AT items INTO DATA(item).
        APPEND VALUE #( %tky    = item-%tky
                        mensaje = |Acción SMOD: OK / Acción ZCAR: OK / Acción Z130: OK Se creó entrega { lv_entrega }| )
               TO lt_upd_item.
      ENDLOOP.

      " 5. Cabecera procesada
      APPEND VALUE #( %tky    = plupload-%tky
                      estado  = 'P'
                      entrega = lv_entrega ) TO lt_upd_cab.
    ENDLOOP.

    " 6. Pedir los cambios a RAP
    MODIFY ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      UPDATE FIELDS ( estado entrega )
      WITH lt_upd_cab

      ENTITY plitem
      UPDATE FIELDS ( mensaje )
      WITH lt_upd_item.

    " 7. Devolver la carga para refrescar la pantalla
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_resultado).

    result = VALUE #( FOR res IN lt_resultado ( %tky = res-%tky %param = res ) ).


  ENDMETHOD.

  METHOD setdatosoc.

    DATA lt_update TYPE TABLE FOR UPDATE zsei_r_cds_plupload\\plupload.

    " 1. Leer la OC que escribió el usuario
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
    ENTITY plupload
    FIELDS ( ordencompra ) WITH CORRESPONDING #( keys )
    RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).

      " 2. Buscar la OC en la CDS liberada
      SELECT SINGLE supplier, purchasingorganization, companycode
      FROM i_purchaseorderapi01
      WHERE purchaseorder = @plupload-ordencompra
      INTO @DATA(ls_oc).

      " 3. Si no existe, ls_oc queda vacío y se limpian los campos
      APPEND VALUE #( %tky = plupload-%tky
                      proveedor = ls_oc-supplier
                      orgcompra = ls_oc-purchasingorganization
                      sociedad = ls_oc-companycode
                     ) TO lt_update.

      CLEAR ls_oc.
    ENDLOOP.

    " 4. Guardar los datos determinados
    MODIFY ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
    ENTITY plupload
       UPDATE FIELDS ( proveedor orgcompra sociedad )
       WITH lt_update.

  ENDMETHOD.

  METHOD setestadoinicial.

    " 1. Leer las cargas que se acaban de crear
    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
    ENTITY plupload
    FIELDS ( estado )
    WITH CORRESPONDING #( keys )
    RESULT DATA(pluploads).

    " 2. Solo las que aún no tienen estado
    DELETE pluploads WHERE estado IS NOT INITIAL.
    CHECK pluploads IS NOT INITIAL.

    " 3. Poner estado 'N' (nuevo)
    MODIFY ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
    ENTITY plupload
    UPDATE FIELDS ( estado )
    WITH VALUE #( FOR plupload IN pluploads
                    ( %tky = plupload-%tky
                      estado = 'N' ) ).

  ENDMETHOD.

  METHOD validarconfig.

    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
   ENTITY plupload
   FIELDS ( proveedor orgcompra marca )
   WITH CORRESPONDING #( keys )
   RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).
      APPEND VALUE #( %tky = plupload-%tky
                      %state_area = 'VAL_CONFIG' )
                    TO reported-plupload.

      " Si falta OC o marca, ya lo reportan las otras validaciones
      CHECK plupload-proveedor IS NOT INITIAL AND plupload-marca IS NOT INITIAL.

      SELECT SINGLE @abap_true
        FROM zsei_r_cds_packlist
        WHERE proveedor = @plupload-proveedor
          AND orgcompra = @plupload-orgcompra
          AND marca     = @plupload-marca
        INTO @DATA(lv_existe).

      IF lv_existe = abap_false.
        APPEND VALUE #( %tky = plupload-%tky ) TO failed-plupload.
        APPEND VALUE #( %tky        = plupload-%tky
                        %state_area = 'VAL_CONFIG'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |No hay configuración para los datos determinados| )
                        %element-marca = if_abap_behv=>mk-on ) TO reported-plupload.
      ENDIF.
      CLEAR lv_existe.
    ENDLOOP.

  ENDMETHOD.

  METHOD validardatos.

    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      FIELDS ( datosexcel  )
      WITH CORRESPONDING #( keys )
      RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).
      APPEND VALUE #( %tky = plupload-%tky %state_area = 'VAL_DATOS' ) TO reported-plupload.

      IF plupload-datosexcel IS INITIAL.
        APPEND VALUE #( %tky = plupload-%tky ) TO failed-plupload.
        APPEND VALUE #( %tky        = plupload-%tky
                        %state_area = 'VAL_DATOS'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |Pegue los datos del packing list| )
                        %element-datosexcel = if_abap_behv=>mk-on ) TO reported-plupload.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validarmarca.

    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
     ENTITY plupload
     FIELDS ( marca )
     WITH CORRESPONDING #( keys )
     RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).
      APPEND VALUE #( %tky = plupload-%tky %state_area = 'VAL_MARCA' ) TO reported-plupload.

      SELECT SINGLE @abap_true
        FROM i_division
        WHERE division = @plupload-marca
        INTO @DATA(lv_existe).

      IF lv_existe = abap_false.
        APPEND VALUE #( %tky = plupload-%tky ) TO failed-plupload.
        APPEND VALUE #( %tky        = plupload-%tky
                        %state_area = 'VAL_MARCA'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |Marca { plupload-marca } no existe| )
                        %element-marca = if_abap_behv=>mk-on ) TO reported-plupload.
      ENDIF.
      CLEAR lv_existe.
    ENDLOOP.

  ENDMETHOD.

  METHOD validarordencompra.

    READ ENTITIES OF zsei_r_cds_plupload IN LOCAL MODE
      ENTITY plupload
      FIELDS ( ordencompra )
      WITH CORRESPONDING #( keys )
      RESULT DATA(pluploads).

    LOOP AT pluploads INTO DATA(plupload).
      " Limpia mensajes anteriores de esta validación en caja de observaciones
      APPEND VALUE #( %tky = plupload-%tky
                      %state_area = 'VAL_OC' )
                    TO reported-plupload.

      SELECT SINGLE @abap_true
         FROM i_purchaseorderapi01
         WHERE purchaseorder = @plupload-ordencompra
         INTO @DATA(lv_existe).

      IF lv_existe = abap_false.
        APPEND VALUE #( %tky = plupload-%tky ) TO failed-plupload.
        APPEND VALUE #( %tky        = plupload-%tky
                        %state_area = 'VAL_OC'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |Nro OC { plupload-ordencompra } no existe| )
                        %element-ordencompra = if_abap_behv=>mk-on ) TO reported-plupload.
      ENDIF.
      CLEAR lv_existe.

    ENDLOOP.


  ENDMETHOD.

ENDCLASS.

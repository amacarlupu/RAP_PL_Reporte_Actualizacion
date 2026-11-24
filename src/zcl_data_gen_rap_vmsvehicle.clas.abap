CLASS zcl_data_gen_rap_vmsvehicle DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES: if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_data_gen_rap_vmsvehicle IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " Molde con los datos de prueba de cada vehículo
    TYPES: BEGIN OF ty_veh,
             vhcle TYPE ztvms_veh_mock-vhcle,
             matnr TYPE ztvms_veh_mock-material,
             charg TYPE ztvms_veh_mock-lote,
             mmsta TYPE ztvms_veh_mock-status,
             color TYPE zsei_vlcvehicle-zzcolor_code,
           END OF ty_veh.


    DATA lt_datos    TYPE STANDARD TABLE OF ty_veh WITH EMPTY KEY.
    DATA lt_vehicle  TYPE STANDARD TABLE OF ztvms_veh_mock  WITH EMPTY KEY.
    DATA lt_zvehicle TYPE STANDARD TABLE OF zsei_vlcvehicle WITH EMPTY KEY.
    DATA lv_vguid    TYPE sysuuid_x16.

    " 1. Los 5 vehículos de prueba de la OC 4510000001
    lt_datos = VALUE #(
      ( vhcle = '0000000001' matnr = 'SCO2SE0' charg = '1000025099' mmsta = 'Z001' color = 'NEG' )
      ( vhcle = '0000000002' matnr = 'CHE1100' charg = '1000025100' mmsta = 'Z001' color = 'BLA' )
      ( vhcle = '0000000003' matnr = 'SCO2SE0' charg = '1000025101' mmsta = 'Z001' color = 'NEG' )
      ( vhcle = '0000000004' matnr = 'SCO2SE0' charg = '1000025102' mmsta = 'Z001' color = 'ROJ' )    " otro color
      ( vhcle = '0000000005' matnr = 'SCO2SE0' charg = '1000025103' mmsta = 'Z009' color = 'NEG' ) ). " status inválido


    " 2. Por cada vehículo: un VGUID nuevo y una fila en cada tabla
    LOOP AT lt_datos INTO DATA(ls_dato).

      TRY.
          lv_vguid = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
          out->write( 'Error generando el VGUID' ).
          RETURN.
      ENDTRY.

      " Tabla que simula VMS estándar (VLCVEHICLE + OC de VLCPORDER)
      APPEND VALUE #( vguid = lv_vguid
                      vhcle = ls_dato-vhcle
                      material = ls_dato-matnr
                      lote = ls_dato-charg
*                      werks = '1000'
                      status = ls_dato-mmsta
                      vin = ''                 " lo llenará Procesar (SMOD)
                      orden_compra = '4510000001' ) TO lt_vehicle.

      " Tabla Z real de la spec (características)
      APPEND VALUE #( vguid        = lv_vguid
                      vhcle        = ls_dato-vhcle
                      matnr        = ls_dato-matnr
                      charg        = ls_dato-charg
                      zzcolor_code = ls_dato-color ) TO lt_zvehicle.
    ENDLOOP.

    " 3. Limpiar y cargar
    DELETE FROM ztvms_veh_mock.
    DELETE FROM zsei_vlcvehicle.

    INSERT ztvms_veh_mock FROM TABLE @lt_vehicle.
    out->write( |ztvms_veh_mock: { sy-dbcnt } vehículos insertados.| ).

    INSERT zsei_vlcvehicle FROM TABLE @lt_zvehicle.
    out->write( |zsei_vlcvehicle: { sy-dbcnt } vehículos insertados.| ).


  ENDMETHOD.

ENDCLASS.

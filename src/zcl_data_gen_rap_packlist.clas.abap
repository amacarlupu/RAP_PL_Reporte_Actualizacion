CLASS zcl_data_gen_rap_packlist DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES: if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_data_gen_rap_packlist IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

*    DELETE FROM ztvms_pack_list.
*    DELETE FROM ztvms_packlst_d.

    TYPES: BEGIN OF ty_prov,
             proveedor TYPE ztvms_pack_list-proveedor,
             marca     TYPE ztvms_pack_list-marca,
           END OF ty_prov.

    DATA lt_prov TYPE STANDARD TABLE OF ty_prov WITH EMPTY KEY.
    DATA lt_cfg  TYPE STANDARD TABLE OF ztvms_pack_list WITH EMPTY KEY.
    DATA lv_ts   TYPE timestampl.

    GET TIME STAMP FIELD lv_ts.

    " Proveedores y marcas de la configuración
    lt_prov = VALUE #( ( proveedor = '0100018700' marca = '01' )
                       ( proveedor = '0100018701' marca = '02' )
                       ( proveedor = '0100018702' marca = '03' )
                       ( proveedor = '0100000000' marca = '01' ) ).


    " Las mismas 4 filas de configuración para cada proveedor
    LOOP AT lt_prov INTO DATA(ls_prov).
      lt_cfg = VALUE #( BASE lt_cfg
        ( proveedor = ls_prov-proveedor marca = ls_prov-marca correlativo = '0001' accion = 'BUSC' dato = 'MATNR' )
        ( proveedor = ls_prov-proveedor marca = ls_prov-marca correlativo = '0002' accion = 'BUSC' dato = 'ZZCOLOR_CODE' )
        ( proveedor = ls_prov-proveedor marca = ls_prov-marca correlativo = '0003' accion = 'SMOD' dato = '' )
        ( proveedor = ls_prov-proveedor marca = ls_prov-marca correlativo = '0004' accion = 'ZCAR' dato = 'ZZENGINE' ) ).
    ENDLOOP.

    " Campos comunes a todas las filas
    LOOP AT lt_cfg ASSIGNING FIELD-SYMBOL(<ls_cfg>).
      <ls_cfg>-orgcompra             = '1000'.
      <ls_cfg>-last_changed_at       = lv_ts.
      <ls_cfg>-local_last_changed_at = lv_ts.
    ENDLOOP.

    " Limpiar y cargar
    DELETE FROM ztvms_pack_list.
    DELETE FROM ztvms_packlst_d.

    INSERT ztvms_pack_list FROM TABLE @lt_cfg.

    IF sy-subrc EQ 0.
      out->write( |Configuración: { sy-dbcnt } registros insertados.| ).
    ELSE.
      out->write( |Error al insertar la configuracion.| ).
    ENDIF.


  ENDMETHOD.

ENDCLASS.

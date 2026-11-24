CLASS zsei_cl_vms_wrapper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_caract,
             nombre TYPE string,     " columna, ej. ZZENGINE
             valor  TYPE string,     " valor del Excel
           END OF ty_caract,
           tt_caract TYPE STANDARD TABLE OF ty_caract WITH EMPTY KEY,
           tt_vguid  TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.

    "SMOD: asigna el VIN al vehículo
    METHODS set_vin
      IMPORTING iv_vguid     TYPE sysuuid_x16
                iv_vin       TYPE ztvms_veh_mock-vin
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    "CMOD/ZCAR: actualiza las características Z del vehículo
    METHODS set_caracteristicas
      IMPORTING iv_vguid     TYPE sysuuid_x16
                it_caract    TYPE tt_caract
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    "Acción colectiva (Z130): crea una entrega para todos los vehículos
    METHODS crear_entrega
      IMPORTING it_vguid          TYPE tt_vguid
      RETURNING VALUE(rv_entrega) TYPE ztvms_pl_header-entrega.

    "! Asigna la entrega creada a los vehículos
    METHODS asignar_entrega
      IMPORTING it_vguid   TYPE tt_vguid
                iv_entrega TYPE ztvms_pl_header-entrega.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zsei_cl_vms_wrapper IMPLEMENTATION.
  METHOD crear_entrega.
    " SIMULADO. En lo real: VELO09_SET_ACTION colectivo con la acción Z130
    "           y luego leer la entrega en I_DeliveryDocumentItem por lote
    SELECT COUNT(*) FROM ztvms_pl_header WHERE entrega <> @space INTO @DATA(lv_cant).
    rv_entrega = |018{ lv_cant + 1 WIDTH = 7 ALIGN = RIGHT PAD = '0' }|.   " ej. 0180000001
  ENDMETHOD.

  METHOD set_caracteristicas.
    " SIMULADO. En lo real: BAPI_VEHICLE_CHANGE_MULTIPLE (CMOD)
    SELECT SINGLE * FROM zsei_vlcvehicle WHERE vguid = @iv_vguid INTO @DATA(ls_zveh).
    IF sy-subrc <> 0.
      RETURN.                                  " rv_ok queda en false
    ENDIF.

    " Dinámico: cada característica va a la columna con su mismo nombre
    LOOP AT it_caract INTO DATA(ls_caract).
      ASSIGN COMPONENT ls_caract-nombre OF STRUCTURE ls_zveh TO FIELD-SYMBOL(<lv_campo>).
      IF sy-subrc <> 0.
        RETURN.                                " columna no existe → error
      ENDIF.
      <lv_campo> = ls_caract-valor.
    ENDLOOP.

    UPDATE zsei_vlcvehicle FROM @ls_zveh.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD set_vin.
    " SIMULADO. En lo real: CALL FUNCTION 'VELO09_SET_ACTION' con acción 'SMOD'
    UPDATE ztvms_veh_mock
        SET vin = @iv_vin,
            status = 'Z002'
        WHERE vguid = @iv_vguid.
    rv_ok = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

  METHOD asignar_entrega.
    " SIMULADO. En lo real: la entrega se consulta en I_DeliveryDocumentItem por lote
    LOOP AT it_vguid INTO DATA(lv_vguid).
      UPDATE ztvms_veh_mock SET entrega = @iv_entrega WHERE vguid = @lv_vguid.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

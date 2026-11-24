@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Simulacion CDS I_VMSVEHICLE'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZSEI_I_CDS_VEH_MOCK
  as select from ztvms_veh_mock
{
  key vguid        as VMSVehicleUUID,
      vhcle        as VMSVehicleInternalID,
      orden_compra as PurchaseOrder,
      material     as Material,
      lote         as VMSVehicleBatch,
      status       as VMSVehiclePrimaryStatus,
      vin          as VehicleIdentificationNumber,
      entrega      as Delivery
}

@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED #'
define root view entity ZSEI_R_CDS_PACKLIST
  as select from ztvms_pack_list as PackList
{
  key proveedor             as proveedor,
  key orgcompra             as orgCompra,
  key marca                 as marca,
  key correlativo           as correlativo,
      accion                as accion,
      dato                  as dato,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as lastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as localLastChangedAt

}

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS Packing List Item'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZSEI_R_CDS_PL_ITEM
  as select from ztvms_pl_item
  association to parent ZSEI_R_CDS_PLUPLOAD as _Upload on $projection.uploadUuid = _Upload.uploadUUID
{
  key item_uuid             as itemUuid,
      upload_uuid           as uploadUuid,
      fila                  as fila,
      material              as material,
      color                 as color,
      vin                   as vin,
      lote                  as lote,
      vguid                 as vguid,
      caracteristicas       as caracteristicas,
      criticidad            as criticidad,
      mensaje               as mensaje,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as localLastChangedAt,
      _Upload
}

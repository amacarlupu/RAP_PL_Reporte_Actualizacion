@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection CDS PL Item'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZSEI_C_CDS_PL_ITEM
  as projection on ZSEI_R_CDS_PL_ITEM
{
  key itemUuid,
      uploadUuid,
      fila,
      material,
      color,
      vin,
      lote,
      vguid,
      caracteristicas,
      criticidad,
      mensaje,
      localLastChangedAt,
      /* Associations */
      _Upload : redirected to parent ZSEI_C_CDS_PLUPLOAD
}

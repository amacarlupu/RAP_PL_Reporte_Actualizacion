@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED #'
define root view entity ZSEI_R_CDS_PLUPLOAD
  as select from ztvms_pl_header as PLUpload
  association [0..1] to ZSEI_I_CDS_ESTADO_VH as _Estado on $projection.estado = _Estado.estado
  composition [0..*] of ZSEI_R_CDS_PL_ITEM   as _Item

{
  key upload_uuid           as uploadUUID,
      orden_compra          as ordenCompra,
      fecha_eta             as fechaEta,
      marca                 as marca,
      proveedor             as proveedor,
      orgcompra             as orgCompra,
      sociedad              as sociedad,
      estado                as estado,
      entrega               as entrega,
      datos_excel           as datosExcel,
      archivo               as archivo,
      mimetype              as mimeType,
      nombre_archivo        as nombreArchivo,
      @Semantics.user.createdBy: true
      created_by            as createdBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as createdAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as lastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as lastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as localLastChangedAt,
      _Item,
      _Estado
}

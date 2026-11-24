@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZSEI_R_CDS_PLUPLOAD'

define root view entity ZSEI_C_CDS_PLUPLOAD
  provider contract transactional_query
  as projection on ZSEI_R_CDS_PLUPLOAD
{
  key uploadUUID,
      ordenCompra,
      fechaEta,
      marca,
      proveedor,
      orgCompra,
      sociedad,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZSEI_I_CDS_ESTADO_VH', element: 'estado' } }]
      @ObjectModel.text.element: [ 'estadoDescripcion' ]
      estado,
      _Estado.descripcion as estadoDescripcion,
      entrega,
      datosExcel,
//      @Semantics.largeObject: { mimeType: 'mimeType',
//                               fileName: 'nombreArchivo',
//                               contentDispositionPreference: #ATTACHMENT }
//      archivo,
//      @Semantics.mimeType: true
//      mimeType,
//      nombreArchivo,
      createdBy,
      createdAt,
      lastChangedBy,
      lastChangedAt,
      localLastChangedAt,
      /* Associations */
      _Estado,
      _Item : redirected to composition child ZSEI_C_CDS_PL_ITEM
}

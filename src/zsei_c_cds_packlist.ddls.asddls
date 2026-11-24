@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZSEI_R_CDS_PACKLIST'
@ObjectModel.semanticKey: [ 'proveedor', 'orgCompra', 'marca', 'correlativo' ]
define root view entity ZSEI_C_CDS_PACKLIST
  provider contract transactional_query
  as projection on ZSEI_R_CDS_PACKLIST
{
  key proveedor,
  key orgCompra,
  key marca,
  key correlativo,
      accion,
      dato,
      lastChangedAt,
      localLastChangedAt
}

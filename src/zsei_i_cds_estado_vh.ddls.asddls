@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Estado de carga'
@Metadata.ignorePropagatedAnnotations: true
//@ObjectModel.resultSet.sizeCategory: #XS      //lo muestra como dropdown
define view entity ZSEI_I_CDS_ESTADO_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZVMS_D_ESTADO' )
{
      @ObjectModel.text.element: [ 'Descripcion' ]
      key value_low as estado,
      text as descripcion
}
where
  language = $session.system_language

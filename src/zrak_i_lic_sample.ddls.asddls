@AbapCatalog.sqlViewName: 'ZRAKILICSAMPLE'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'RAK CJS - sample license application'
define view ZRAK_I_LIC_SAMPLE
  as select from zrak_t_licsmp
{
  key lic_id        as LicId,
      trade_name    as TradeName,
      activity_key  as ActivityKey,
      jurisdiction  as Jurisdiction,
      legal_struct  as LegalStructure,
      share_cnt     as ShareholderCount,
      needs_impexp  as NeedsImportExport,
      start_date    as StartDate,
      description   as Description,
      status        as Status,
      created_by    as CreatedBy,
      created_on    as CreatedOn
}

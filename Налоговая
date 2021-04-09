/*
 Пример SOAP запроса на веб-сервис Налоговой
 https://github.com/virex-84/SQL
*/

--см. http://npchk.nalog.ru/FNSNDSCAWS_2?wsdl

declare
 @request xml
,@username varchar(max)
,@password varchar(max)
,@result XML

/*
set @request ='
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<SOAP-ENV:Body>
<NdsRequest2 xmlns="http://ws.unisoft/FNSNDSCAWS2/Request">
<NP INN="7707083893" KPP="773601001" DT="01.01.2001"/>
<NP INN="7707083893" KPP="773601002" DT="01.01.2002"/>
</NdsRequest2>
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>';
*/

--1 сформируем запрос самостоятельно
declare @body xml
;with XMLNAMESPACES ( default 'http://ws.unisoft/FNSNDSCAWS2/Request')
 select @body=(
   select
   --сначала объявляются атрибуты
    '7707083893' as [NP/@INN]
   ,'773601001' as [NP/@KPP]
   ,'01.01.2001' as [NP/@DT]
   --затем объявляется нода
   ,'' as NP
   FOR XML path('NdsRequest2'), type, ELEMENTS
 )

 --1 сформируем запрос самостоятельно из таблицы
 ;with XMLNAMESPACES ( default 'http://ws.unisoft/FNSNDSCAWS2/Request')
 select @body=(
 select (
   select
    INN as [@INN]
   ,KPP as [@KPP]
   from (
     select INN='7707083893',KPP='773601001'
	 union all 
	 select INN='7707083893',KPP='773601002'
   ) as [NP]
   FOR XML PATH('NP'),TYPE
   
   )FOR XML path('NdsRequest2'), type, ELEMENTS
 )

;with XMLNAMESPACES (
default 'http://ws.unisoft/FNSNDSCAWS2/Request',
'http://www.w3.org/2001/XMLSchema-instance' as xsi,
'http://www.w3.org/2001/XMLSchema' as xsd,
'http://schemas.xmlsoap.org/soap/envelope/' as [soap]
)
select @request=(
  select(
    select @body
    FOR XML path('soap:Body'), type
  ) FOR XML path('soap:Envelope')
)
select [Запрос]=@request

--2 Вызов WebMethod-а
EXEC dbo.spSOAPMethodCallAutorization 'https://npchk.nalog.ru:443/FNSNDSCAWS_2', 'NdsRequest2', @username,@password, @Request, @result OUT

select [Результат]=@result

--3 парсим результат
;WITH XMLNAMESPACES(DEFAULT 'http://web.cbr.ru/')
select 
   [Дата проверки ФЛ]=x.Rec.value('(/*:NdsResponse2/@DTActFL)[1]', 'varchar(max)')
 , [Дата проверки ЮЛ]=x.Rec.value('(/*:NdsResponse2/@DTActUL)[1]', 'varchar(max)')
 , [ИНН]=x.Rec.value('(@INN)[1]', 'varchar(max)')
 , [КПП]=x.Rec.value('(@KPP)[1]', 'varchar(max)')
 , [Статус контрагента]=x.Rec.value('(@State)[1]', 'varchar(max)')
 , [Расшифровка статуса]=
   case x.Rec.value('(@State)[1]', 'varchar(max)')
     when '0' then 'Налогоплательщик зарегистрирован в ЕГРН и имел статус действующего в указанную дату'
     when '1' then 'Налогоплательщик зарегистрирован в ЕГРН, но не имел статус действующего в указанную дату'
     when '2' then 'Налогоплательщик зарегистрирован в ЕГРН'
     when '3' then 'Налогоплательщик с указанным ИНН зарегистрирован в ЕГРН, КПП не соответствует ИНН или не указан*'
     when '4' then 'Налогоплательщик с указанным ИНН не зарегистрирован в ЕГРН'
     when '5' then 'Некорректный ИНН'
     when '6' then 'Недопустимое количество символов ИНН'
     when '7' then 'Недопустимое количество символов КПП'
     when '8' then 'Недопустимые символы в ИНН'
     when '9' then 'Недопустимые символы в КПП'
     when '11' then 'Некорректный формат даты'
     when '12' then 'Некорректная дата (ранее 01.01.1991 или позднее текущей даты)'
   end
from 
@result.nodes('/*:NdsResponse2/*:NP') as x(Rec)

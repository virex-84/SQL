/*
 Пример SOAP запроса на веб-сервис ЦБ РФ
 https://github.com/virex-84/SQL
*/

declare
 @request xml
,@username varchar(max)
,@password varchar(max)
,@result XML

--0 присвоим готовый запрос
--set @request ='
--<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
--  <soap:Body>
--    <AllDataInfoXML xmlns="http://web.cbr.ru/" />
--  </soap:Body>
--</soap:Envelope>';

--1 сформируем запрос самостоятельно
declare @body xml
;with XMLNAMESPACES ( default 'http://web.cbr.ru/')
 select @body=(
   select ''
   FOR XML path('AllDataInfoXML'), type, ELEMENTS
 )

;with XMLNAMESPACES (
default 'http://web.cbr.ru/',
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
EXEC dbo.spSOAPMethodCallAutorization 'https://www.cbr.ru/DailyInfoWebServ/DailyInfo.asmx?op=AllDataInfoXML', 'http://web.cbr.ru/AllDataInfoXML', @username,@password, @Request, @result OUT

select [Результат]=@result

--3 парсим результат
;WITH XMLNAMESPACES(DEFAULT 'http://web.cbr.ru/')
select 
 [Курс доллара]=x.Rec.query('*:MainIndicatorsVR/*:Currency/*:USD/*:curs').value('.', 'varchar(max)') 
,[Золото]=x.Rec.value('(*:MainIndicatorsVR/*:Metall/*:Золото[@val=""]/@old_val)[1]', 'varchar(max)')
,[Инфляция]=x.Rec.value('(*:MainIndicatorsVR/*:Inflation/@val)[1]', 'varchar(max)')
,[Действующая ключевая ставка %]=x.Rec.value('(*:KEY_RATE/@val)[1]', 'varchar(max)')
,[Международные резервы млрд долл. США]=x.Rec.value('(*:Macro/*:M_rez/@val)[1]', 'varchar(max)')
from 
@result.nodes('/AllDataInfoXMLResponse/*:AllDataInfoXMLResult/*:AllData') as x(Rec)

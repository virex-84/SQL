SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
  Обновление поля в пользовательской Таблице
  Подразумевается что у таблицы первичный ключ id+имя_таблицы

  Примеры обновления:

  Текст
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', 'иванов иван иванович'
  
  Дата
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', '2018-05-23'

  Идентификатор
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', 'D6676701-E836-4E9C-8055-9FFC3FC6F62B'

  Битовое поле
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', '0'

  Число с плавающей точкой (money/float)
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', '1.4'

  Блоб поле (varbinary(max) или image) как varchar(max) 
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', '0x42444F4...'

  Блоб поле как varchar(max) в кодировке Base64
  exec spUpdateFieldInTable '00000000-0000-0000-0000-000000000000', 'MyTable', 'MyField', 'QkRPQwEAAAAAd...', 'base64'

  Пример ниже:
--создаем таблицу
--drop table TestTable
create table TestTable (
IDTestTable  uniqueidentifier PRIMARY KEY DEFAULT newid(), 
Field1 varchar(256),
Field2 int
)

--вставляем запись
insert into TestTable(IDTestTable,Field1,Field2)
select '52FF6DB8-C125-4CA9-8D41-0C63F1655A08','text',1

--проверяем
select * from TestTable

--обновляем поля
exec spUpdateFieldInTable2 '52FF6DB8-C125-4CA9-8D41-0C63F1655A08', 'TestTable', 'Field1', 'text2'
exec spUpdateFieldInTable2 '52FF6DB8-C125-4CA9-8D41-0C63F1655A08', 'TestTable', 'Field2', '3'

--еще раз проверяем
select * from TestTable

*/
create procedure [dbo].[spUpdateFieldInTable]
@ID uniqueidentifier,	        --ID записи в таблице
@Table varchar(1024),			--наименование таблицы
@Name varchar(1024),			--наименование поля для обновления
@Value varchar(max),			--значение поля
@ColumnType varchar(max)=null	--тип поля(не обязательный параметр)
AS

declare
  @error varchar(max)
, @IDName varchar(max)
, @ColumnName varchar(max)
, @ColumnValue varchar(max)
, @SQL NVARCHAR(max)

, @count_rows int; 

BEGIN TRY

  --ищем таблицу
  if (select count(*) from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=@Table)=0 begin
    set @error=isnull('Не найдена таблица '+@Table,'Название таблицы не определено')
    raiserror (@error, 16, 1);--выходим в catch
  end

  set @IDName='ID'+@Table
  --ищем название ID
  if (select count(*) from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=@Table and COLUMN_NAME=@IDName)=0 begin
    set @error='Не найден ID '+@IDName+ ' в таблице '+@Table
    raiserror (@error, 16, 1);--выходим в catch
  end

  set @IDName='ID'+@Table
  --ищем название ID
  if (select count(*) from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=@Table and COLUMN_NAME=@Name)=0 begin
	set @error=isnull('Не найдено поле '+@Name+ ' в таблице '+@Table,'Название поля не определено')
    raiserror (@error, 16, 1);--выходим в catch
  end

  if @ID is null
    raiserror ('Не указан ID таблицы', 16, 1);--выходим в catch

  --ищем строку в таблице
  BEGIN TRY
    set @SQL='select @count_rows=count(*) from '+@Table+' where '+@IDName+'='''+cast(@ID as varchar(max))+'''';
    exec sp_executesql @SQL, N'@count_rows varchar(30) OUTPUT', @count_rows=@count_rows OUTPUT
	if @count_rows=0 begin
	  set @error='Не найдена запись в '+@Table
	  raiserror (@error, 16, 1);--выходим в catch 
	end
  END TRY
  BEGIN CATCH
    if @count_rows is null
	  set @error='Ошибка поиска: '+ERROR_MESSAGE()
	else 
	  set @error=ERROR_MESSAGE()

    raiserror (@error, 16, 1);--выходим в catch
  END CATCH;

  --определяем название поля
  set @ColumnName=@Name

  --получаем тип значения (если не прописали заранее при вызове этой процедуры)
  if @ColumnType is null
    select @ColumnType=(select DATA_TYPE from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=@Table and COLUMN_NAME=@ColumnName )

  --для blob полей (varbinary,image) преобразуем в текст через CONVERT
  --для кодировки (base64) раскодируем и преобразуем в текст через CONVERT
  set @ColumnValue= 
    CASE 
	  WHEN @ColumnType IN ('binary','varbinary','image') THEN CONVERT(VARCHAR(max), @Value, 1)
	  WHEN @ColumnType IN ('base64') THEN CONVERT(VARCHAR(max),CAST( @Value as XML ).value('.','varbinary(max)'), 1)
	--для всех остальных типов - конвертируем в текст
    ELSE isnull(cast(@Value as varchar(max)),'NULL')
    END
  
  --формируем динамический запрос
  if @ColumnType in ('binary','varbinary','image','base64')
    set @SQL=N'update '+@Table+' set '+@ColumnName+'=convert(varbinary(max),@ColumnValue,1) where '+@IDName+'='''+cast(@ID as varchar(max))+''''
  else
    --все остальные типы можно указать как в тектовом запросе
    set @SQL=N'update '+@Table+' set '+@ColumnName+'=@ColumnValue where '+@IDName+'='''+cast(@ID as varchar(max))+'''' 

  --выполняем запрос
  exec sys.sp_executesql
    @SQL,
    N'@ColumnValue varchar(max)', --указываем типы входящих параметров
    @ColumnValue

END TRY
BEGIN CATCH
  
  --вывод сообщения
  set @error=ERROR_MESSAGE()
  raiserror (@error, 16, 1);

END CATCH;

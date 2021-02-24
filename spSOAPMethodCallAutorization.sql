SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
 Процедура запуска SOAP сервиса
*/
CREATE PROCEDURE [dbo].[spSOAPMethodCallAutorization] (
	 @URL		  varchar(max) = NULL
	,@SOAPAction varchar(max) = NULL
	,@UserName    varchar(max) = NULL
	,@Password    varchar(max) = NULL
	,@Request     XML = NULL
	,@Result     XML = NULL	OUTPUT
) AS BEGIN

	DECLARE	 @OLEObject		Int
		,@HTTPStatus		Int
		,@ErrCode		Int
		,@ErrMethod		varchar(max)
		,@ErrSource		varchar(max)
		,@ErrDescription	varchar(max)
		,@Header	XML	= NULL

	EXEC @ErrCode = sys.sp_OACreate 'MSXML2.ServerXMLHTTP', @OLEObject OUT
	IF (@ErrCode = 0) BEGIN
	  --Базовая аутентификация при указанных @UserName, @Password
		EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'open',NULL ,'POST' ,@URL ,'false' , @UserName, @Password IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'open'		GOTO Error END

		EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'setRequestHeader'	,NULL ,'Content-Type'	,'text/xml; charset="utf-8"' IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'setRequestHeader'	GOTO Error END

		--EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'setRequestHeader'	,NULL ,'Host'	,'host.ru:50000' IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'setRequestHeader'	GOTO Error END
		--EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'setRequestHeader'	,NULL ,'User-Agent'	,'Borland SOAP 1.2' IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'setRequestHeader'	GOTO Error END

		declare @len int
        set @len = len(cast(@Header as nvarchar(max))) 
        EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'setRequestHeader'	,NULL ,'Content-Length', @len IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'setRequestHeader'	GOTO Error END

		if @SOAPAction is not null
		EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'setRequestHeader'	,NULL ,'SOAPAction'	,@SOAPAction IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'setRequestHeader'	GOTO Error END

		--отправка
		EXEC @ErrCode = sys.sp_OAMethod @OLEObject ,'send'		,NULL ,@Request	IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'send'		GOTO Error END

		EXEC @ErrCode = sys.sp_OAGetProperty @OLEObject ,'status' ,@HTTPStatus OUT IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'status'		GOTO Error END
		IF (@HTTPStatus IN (200,500)) BEGIN
			DECLARE	@Response TABLE ( Response NVarChar(max) )
			--SET TEXTSIZE 2147483647;
			INSERT	@Response
			EXEC @ErrCode = sys.sp_OAGetProperty @OLEObject ,'responseText' IF (@ErrCode != 0) BEGIN SET @ErrMethod = 'responseText'	GOTO Error END

			;WITH XMLNAMESPACES (
				 'http://www.w3.org/2001/XMLSchema-instance'	AS [xsi]
				,'http://www.w3.org/2001/XMLSchema'		AS [xsd]
				,'http://schemas.xmlsoap.org/soap/envelope/'	AS [soap])
			SELECT	 @Header	= R.X.query('/soap:Envelope/soap:Header/*')
				,@Result		= R.X.query('/soap:Envelope/soap:Body/*')
			FROM	@Response CROSS APPLY (SELECT Convert(XML,Replace(Response,' encoding="utf-8"','')) AS X) R
			-- Fault
			;WITH XMLNAMESPACES (
				 'http://www.w3.org/2001/XMLSchema-instance'	AS [xsi]
				,'http://www.w3.org/2001/XMLSchema'		AS [xsd]
				,'http://schemas.xmlsoap.org/soap/envelope/'	AS [soap])
			SELECT	 @ErrMethod	= @SOAPAction
				,@ErrSource	= @Result.value('(/soap:Fault/faultcode)[1]'	,'varchar(max)')
				,@ErrDescription= @Result.value('(/soap:Fault/faultstring)[1]'	,'varchar(max)')
			WHERE	@HTTPStatus = 500
		END ELSE
			SELECT	 @ErrMethod	= 'send'
				,@ErrSource	= 'spSOAPMethod'
				,@ErrDescription= 'Ошибочный статус HTTP ответа "' + Convert(VarChar,@HTTPStatus) + '"'

		GOTO Destroy
	Error: EXEC @ErrCode = sys.sp_OAGetErrorInfo @OLEObject ,@ErrSource OUT ,@ErrDescription OUT
	Destroy:EXEC @ErrCode = sys.sp_OADestroy @OLEObject
		IF (@ErrSource IS NOT NULL) BEGIN

			set @ErrMethod=isnull(@ErrMethod,'')
			set @ErrSource=isnull(@ErrSource,'')
			set @ErrDescription=isnull(@ErrDescription,'')


			RAISERROR('Ошибка при выполнении метода "%s" в "%s": %s',18,1,@ErrMethod,@ErrSource,@ErrDescription)
			IF (@@TranCount > 0 AND XACT_STATE() != 0)
				ROLLBACK
			RETURN	@@Error
		END
	END ELSE BEGIN
		RAISERROR('Ошибка при создании OLE объекта "MSXML2.ServerXMLHTTP"',18,1)
		RETURN	@@Error
	END
END

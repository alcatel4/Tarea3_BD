CREATE PROCEDURE dbo.procEliminarEmpleado
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdEmpleado INT
    DECLARE @IdUsuarioSistema INT
    DECLARE @Descripcion VARCHAR(256)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuarioSistema = u.id
        FROM dbo.Usuario AS u
        WHERE (u.Tipo = 1)

        SELECT @IdEmpleado = e.id
        FROM dbo.Empleado AS e
        WHERE (e.DocumentoIdentidad = @inValorDocumentoIdentidad)

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50012
            RETURN
        END

        SET @Descripcion = '{"Documento":"' + @inValorDocumentoIdentidad + '"}'

        BEGIN TRANSACTION

            UPDATE dbo.Empleado
            SET EsActivo = 0
            WHERE (id = @IdEmpleado)

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                10
                ,'127.0.0.1'
                ,GETDATE()
                ,@Descripcion
                ,@IdUsuarioSistema
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        IF (XACT_STATE() <> 0)
            ROLLBACK TRANSACTION

        INSERT INTO dbo.DBError (
            UserName
            ,Number
            ,State
            ,Severity
            ,Line
            ,[Procedure]
            ,Message
            ,DateTime
        )
        VALUES (
            @inValorDocumentoIdentidad
            ,ERROR_NUMBER()
            ,ERROR_STATE()
            ,ERROR_SEVERITY()
            ,ERROR_LINE()
            ,ERROR_PROCEDURE()
            ,ERROR_MESSAGE()
            ,GETDATE()
        )

        SET @outResultCode = 50008

    END CATCH
END
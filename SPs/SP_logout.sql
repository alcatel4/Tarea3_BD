CREATE PROCEDURE dbo.procLogout
    @inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @idUsuario INT

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @idUsuario = u.id
        FROM dbo.Usuario AS u
        WHERE (u.UserName = @inUsername)

        BEGIN TRANSACTION

            INSERT INTO dbo.BitacoraEvento (
                IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
                ,idTipoEvento
            )
            VALUES (
                @inPostInIP
                ,GETDATE()
                ,''
                ,@idUsuario
                ,4
            )

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION

        SET @outResultCode = 50008

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
            @inUsername
            ,ERROR_NUMBER()
            ,ERROR_STATE()
            ,ERROR_SEVERITY()
            ,ERROR_LINE()
            ,ERROR_PROCEDURE()
            ,ERROR_MESSAGE()
            ,GETDATE()
        )

    END CATCH
END
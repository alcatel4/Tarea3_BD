CREATE PROCEDURE dbo.procObtenerTipoUsuario
    @inUsername VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    SET @outResultCode = 0

    BEGIN TRY

        SELECT u.Tipo
        FROM dbo.Usuario AS u
        WHERE (u.Username = @inUsername)

    END TRY
    BEGIN CATCH

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

        SET @outResultCode = 50008

    END CATCH
END
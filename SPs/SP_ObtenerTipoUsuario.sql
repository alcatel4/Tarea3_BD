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
        SET @outResultCode = 50008
    END CATCH
END
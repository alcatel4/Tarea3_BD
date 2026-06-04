CREATE PROCEDURE dbo.procObtenerPuestos
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    SET @outResultCode = 0

    BEGIN TRY

        SELECT p.id
            ,p.Nombre
        FROM dbo.Puesto AS p
        ORDER BY p.Nombre ASC

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
            SYSTEM_USER
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
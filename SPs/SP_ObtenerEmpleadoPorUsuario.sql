CREATE PROCEDURE dbo.procObtenerEmpleadoPorUsuario
    @inUsername VARCHAR(64)
    ,@outResultCode INT OUTPUT

AS
BEGIN

    SET NOCOUNT ON
    SET @outResultCode = 0

    BEGIN TRY

        SELECT
            e.id AS idEmpleado
            ,e.Nombre AS Nombre
        FROM dbo.Empleado e
        INNER JOIN dbo.Usuario u ON (u.id = e.idUsuario)
        WHERE (u.UserName = @inUsername)

    END TRY
    BEGIN CATCH

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
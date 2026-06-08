CREATE PROCEDURE dbo.procObtenerEmpleado
    @inIdEmpleado   INT
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    SET @outResultCode = 0

    BEGIN TRY

        SELECT e.id
            ,e.Nombre
            ,e.TipoDocumentoIdentidad
            ,e.DocumentoIdentidad
            ,e.CuentaBancaria
            ,e.idPuesto
            ,p.Nombre AS NombrePuesto
            ,e.FechaContratacion
        FROM dbo.Empleado AS e
        INNER JOIN dbo.Puesto AS p ON (p.id = e.idPuesto)
        WHERE (e.id = @inIdEmpleado)

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
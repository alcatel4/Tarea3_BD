CREATE PROCEDURE dbo.procListarEmpleados
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    SET @outResultCode = 0

    BEGIN TRY

        SELECT e.id
            ,e.Nombre
            ,p.Nombre AS Puesto
        FROM dbo.Empleado AS e
        INNER JOIN dbo.Puesto AS p ON (p.id = e.idPuesto)
        ORDER BY e.Nombre ASC

    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008
    END CATCH
END
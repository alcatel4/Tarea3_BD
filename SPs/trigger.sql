CREATE TRIGGER dbo.trg_AsociarDeduccionObligatoria
ON dbo.Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdEmpleado INT
    DECLARE @IdTipoDeduccion INT
    DECLARE @Porcentaje DECIMAL(6,4)
    DECLARE @FechaContratacion DATETIME

    SELECT @IdEmpleado = i.id
        ,@FechaContratacion = i.FechaContratacion
    FROM inserted AS i

    SELECT @IdTipoDeduccion = td.id
        ,@Porcentaje = td.Porcentaje
    FROM dbo.TipoDeduccion AS td
    WHERE (td.FlagObligatorio = 1)

    INSERT INTO dbo.EmpXTipoDeduccionPorcentual (
        FechaInicio
        ,FechaFin
        ,Porcentaje
        ,idEmpleado
        ,idTipoDeduccion
    )
    VALUES (
        @FechaContratacion
        ,'9999-12-31'
        ,@Porcentaje
        ,@IdEmpleado
        ,@IdTipoDeduccion
    )
END
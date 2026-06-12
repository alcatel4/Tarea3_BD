CREATE PROCEDURE dbo.procInsertarEmpleado
    @inValorDocumentoIdentidad VARCHAR(20)
    ,@inNombre VARCHAR(100)
    ,@inPuesto VARCHAR(100)
    ,@inCuentaBancaria VARCHAR(30)
    ,@inFechaContratacion DATETIME
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdPuesto INT
    DECLARE @IdUsuario INT
    DECLARE @IdUsuarioSistema INT
    DECLARE @IdEmpleado INT
    DECLARE @IdTipoDeduccionObl INT
    DECLARE @PorcentajeObl DECIMAL(6,4)
    DECLARE @Descripcion VARCHAR(256)

    SET @outResultCode = 0

    BEGIN TRY

        -- Obtener usuario administrador del sistema para bitacora
        SELECT @IdUsuarioSistema = u.id
        FROM dbo.Usuario AS u
        WHERE (u.Tipo = 1)

        -- Obtener id del puesto por nombre
        SELECT @IdPuesto = p.id
        FROM dbo.Puesto AS p
        WHERE (p.Nombre = @inPuesto)

        IF (@IdPuesto IS NULL)
        BEGIN
            SET @outResultCode = 50004
            RETURN
        END

        -- Verificar que no exista ya el empleado
        IF EXISTS (
            SELECT 1
            FROM dbo.Empleado AS e
            WHERE (e.DocumentoIdentidad = @inValorDocumentoIdentidad)
        )
        BEGIN
            SET @outResultCode = 50004
            RETURN
        END

        -- Obtener deduccion obligatoria
        SELECT @IdTipoDeduccionObl = td.id
            ,@PorcentajeObl = td.Porcentaje
        FROM dbo.TipoDeduccion AS td
        WHERE (td.FlagObligatorio = 1)

        -- Preparar descripcion para bitacora
        SET @Descripcion = '{"Nombre":"' + @inNombre +
            '","Documento":"' + @inValorDocumentoIdentidad +
            '","Puesto":"' + @inPuesto +
            '","CuentaBancaria":"' + @inCuentaBancaria + '"}'

        BEGIN TRANSACTION

            INSERT INTO dbo.Usuario (
                UserName
                ,Password
                ,Tipo
            )
            VALUES (
                @inValorDocumentoIdentidad
                ,'1234'
                ,2
            )

            SET @IdUsuario = SCOPE_IDENTITY()

            INSERT INTO dbo.Empleado (
                TipoDocumentoIdentidad
                ,DocumentoIdentidad
                ,Nombre
                ,CuentaBancaria
                ,idPuesto
                ,idUsuario
                ,FechaContratacion
            )
            VALUES (
                'Cedula'
                ,@inValorDocumentoIdentidad
                ,@inNombre
                ,@inCuentaBancaria
                ,@IdPuesto
                ,@IdUsuario
                ,@inFechaContratacion
            )

            SET @IdEmpleado = SCOPE_IDENTITY()

            INSERT INTO dbo.EmpXTipoDeduccionPorcentual (
                FechaInicio
                ,FechaFin
                ,Porcentaje
                ,idEmpleado
                ,idTipoDeduccion
            )
            VALUES (
                @inFechaContratacion
                ,'9999-12-31'
                ,@PorcentajeObl
                ,@IdEmpleado
                ,@IdTipoDeduccionObl
            )

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                6
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
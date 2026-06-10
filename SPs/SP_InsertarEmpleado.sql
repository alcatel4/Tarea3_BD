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

    DECLARE @IdPuesto  INT
    DECLARE @IdUsuario INT

    SET @outResultCode = 0

    BEGIN TRY

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
        IF EXISTS (SELECT 1 FROM dbo.Empleado AS e WHERE (e.DocumentoIdentidad = @inValorDocumentoIdentidad))
        BEGIN
            SET @outResultCode = 50004
            RETURN
        END

        BEGIN TRANSACTION

            -- Crear usuario para el empleado
            INSERT INTO dbo.Usuario (UserName, Password, Tipo)
            VALUES (
                @inValorDocumentoIdentidad
                ,'1234'
                ,2
            )

            SET @IdUsuario = SCOPE_IDENTITY()

            -- Insertar empleado
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
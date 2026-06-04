CREATE PROCEDURE dbo.procImpersonarEmpleado
    @inIdEmpleado INT
    ,@inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuario INT
    DECLARE @UsernameEmpleado VARCHAR(64)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuario = u.id
        FROM dbo.Usuario AS u
        WHERE (u.UserName = @inUsername)

        SELECT @UsernameEmpleado = u.UserName
        FROM dbo.Empleado AS e
        INNER JOIN dbo.Usuario AS u ON (u.id = e.idUsuario)
        WHERE (e.id = @inIdEmpleado)

        SELECT @UsernameEmpleado AS UsernameEmpleado

        BEGIN TRANSACTION

            INSERT INTO dbo.BitacoraEvento (
                idTipoEvento
                ,IpPostIn
                ,PostTime
                ,Descripcion
                ,idUsuario
            )
            VALUES (
                5
                ,@inPostInIP
                ,GETDATE()
                ,CAST(@inIdEmpleado AS VARCHAR)
                ,@IdUsuario
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
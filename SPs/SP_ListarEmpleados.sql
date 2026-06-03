CREATE PROCEDURE dbo.procListarEmpleados
    @inFiltro VARCHAR(100)
    ,@inUsername VARCHAR(64)
    ,@inPostInIP VARCHAR(64)
    ,@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @IdUsuario INT
    DECLARE @DescripcionEvento VARCHAR(100)

    SET @outResultCode = 0

    BEGIN TRY

        SELECT @IdUsuario = u.id
        FROM dbo.Usuario AS u
        WHERE (u.UserName = @inUsername)

        IF (@inFiltro = '')
        BEGIN
            SELECT e.id
                ,e.Nombre
                ,p.Nombre AS Puesto
            FROM dbo.Empleado AS e
            INNER JOIN dbo.Puesto AS p ON (p.id = e.idPuesto)
            ORDER BY e.Nombre ASC
        END
        ELSE
        BEGIN
            SELECT e.id
                ,e.Nombre
                ,p.Nombre AS Puesto
            FROM dbo.Empleado AS e
            INNER JOIN dbo.Puesto AS p ON (p.id = e.idPuesto)
            WHERE (e.Nombre LIKE '%' + @inFiltro + '%')
            ORDER BY e.Nombre ASC

            SET @DescripcionEvento = @inFiltro
        END

        IF (@inFiltro <> '')
        BEGIN
            BEGIN TRANSACTION

                INSERT INTO dbo.BitacoraEvento (
                    idTipoEvento
                    ,IpPostIn
                    ,PostTime
                    ,Descripcion
                    ,idUsuario
                )
                VALUES (
                    4
                    ,@inPostInIP
                    ,GETDATE()
                    ,@DescripcionEvento
                    ,@IdUsuario
                )

            COMMIT TRANSACTION
        END

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
# Compilar y cargar ficheros con modulos necesarios
Code.require_file("nodo_remoto.exs", __DIR__)
Code.require_file("servidor_gv.exs", __DIR__)
Code.require_file("cliente_gv.exs", __DIR__)

#Poner en marcha el servicio de tests unitarios con :
# timeout : ajuste de tiempo máximo de ejecución de todos los tests, en miliseg.
# seed: 0 , para que la ejecucion de tests no tenga orden aleatorio
# exclusion de ejecución de aquellos tests que tengan el tag :deshabilitado
ExUnit.start([timeout: 10000, seed: 0, exclude: [:deshabilitado]])

defmodule  GestorVistasTest do

    use ExUnit.Case

    # @moduletag timeout 100  para timeouts de todos lo test de este modulo

    # Preparación de contexto de tests de integración
    # Para gestionar nodos y maquinas
    setup_all do
        # Poner en marcha los servidores, obtener nodos
        #maquinas = ["127.0.0.1", "192.168.1.172",
        #            "192.168.1.173", "127.0.0.1"]
        maquinas = ["127.0.0.1"]
            # devuelve una mapa de nodos del servidor y clientes
        nodos = startServidores(maquinas)

        on_exit fn ->
                    #eliminar_nodos Elixir y epmds en maquinas
                    #stopServidores(nodos, maquinas)
                    stopServidores(nodos, maquinas)
                end

        {:ok, nodos}
    end


    # Test 1 : No deberia haber primario
    ##@tag :deshabilitado
    test "No deberia haber primario", %{c1: c1} do
        IO.puts("Test: No deberia haber primario ...")

        p = ClienteGV.primario(c1)

        assert p == :undefined

        IO.puts(" ... Superado")
    end


    # Test 2 : primer primario
    ##@tag :deshabilitado
    test "Primer primario", %{c1: c} do
        IO.puts("Test: Primer primario ...")

        primer_primario(c, ServidorGV.latidos_fallidos() * 2)
        comprobar_tentativa(c, c, :undefined, 1)

        IO.puts(" ... Superado")
    end


    # Test 3 : primer nodo copia
    ##@tag :deshabilitado
    test "Primer nodo copia", %{c1: c1, c2: c2} do
        IO.puts("Test: Primer nodo copia ...")

        {vista, _} = ClienteGV.latido(c1, -1)  # Solo interesa vista tentativa
        primer_nodo_copia(c1, c2, ServidorGV.latidos_fallidos() * 2)

        # validamos nueva vista por estar completa
        ClienteGV.latido(c1, vista.num_vista + 1)

        comprobar_valida(c1, c1, c2, vista.num_vista + 1)

        IO.puts(" ... Superado")
    end


    ## Test 4 : Después, Copia (C2) toma el relevo si Primario falla.,
    ##@tag :deshabilitado
    test "Copia releva primario", %{c2: c2} do
        IO.puts("Test: copia toma relevo si primario falla ...")

        {vista, _} = ClienteGV.latido(c2, 2)

        copia_releva_primario(c2, vista.num_vista,
                                            ServidorGV.latidos_fallidos() * 2)
        comprobar_tentativa(c2, c2, :undefined, vista.num_vista + 1)

        IO.puts(" ... Superado")
    end

    ## Test 5 : Servidor rearrancado (C1) se convierte en copia.
    ##@tag :deshabilitado
    test "Servidor rearrancado se conviert en copia", %{c1: c1, c2: c2} do
        IO.puts("Test: Servidor rearrancado se conviert en copia ...")

        {vista, _} = ClienteGV.latido(c2, 2)   # vista tentativa
        servidor_rearranca_a_copia(c1, c2, 2, ServidorGV.latidos_fallidos() * 2)

        # validamos nueva vista por estar DE NUEVO completa
        # vista valida debería ser 4
        ClienteGV.latido(c2, vista.num_vista + 1)

        comprobar_valida(c2, c2, c1, vista.num_vista + 1)

        IO.puts(" ... Superado")
    end

    ## Test 6 : Servidor en espera (C3) se convierte en copia si primario falla.
    ##@tag :deshabilitado
    test "Servidor en espera se convierte en copia", %{c1: c1, c3: c3} do
        IO.puts("Test: Servidor en espera se convierte en copia ...")

        ClienteGV.latido(c3, 0) # nuevo servidor en espera
        {vista, _} = ClienteGV.latido(c1, 4)   # vista tentativa
        IO.inspect espera_pasa_a_copia(c1, c3, 4, ServidorGV.latidos_fallidos() * 2)

        # validamos nueva vista por estar DE NUEVO completa
        # vista valida debería ser 5
        ClienteGV.latido(c1, vista.num_vista + 1)
        comprobar_valida(c1, c1, c3, vista.num_vista + 1)

        IO.puts(" ... Superado")
    end

    ## Test 7 : Primario rearrancado (C2) tratado como caido y
    #           es convertido en nodo en espera.
    #       rearrancado_caido(C1, C3),
    ##@tag :deshabilitado
    test "Primario rearrancado (C2) tratado como caido, convertido en nodo en espera", %{c1: c1, c2: c2, c3: c3} do
      IO.puts("Test: Primario rearrancado tratado como caido y convertido en nodo en espera ...")

      ClienteGV.latido(c2, 0) ##Servidor rearrancado
      {vista, _} = ClienteGV.latido(c1, 5)   # vista tentativa
      rearrancado_caido(c1,c3, 5)

      ClienteGV.latido(c1, vista.num_vista)
      ##Si c2 no entrara como nodo en espera, el numero de vista aumentaria en una unidad
      comprobar_valida(c1, c1, c3, vista.num_vista)
      IO.puts(" ... Superado")

    end

    ## Test 8 : Servidor de vistas espera a que primario confirme vista
    ##          pero este no lo hace.
    ##          Poner C3 como Primario, C1 como Copia, C2 para comprobar
    ##          - C3 no confirma vista en que es primario,
    ##          - Cae, pero C1 no es promocionado porque C3 no confimo !
    # primario_no_confirma_vista(C1, C2, C3),
    @tag :deshabilitado
    test "Primario no confirma", %{c1: c1, c2: c2, c3: c3} do

      ClienteGV.latido(c3, 0) ##Primario
      ClienteGV.latido(c1, 0) ##Copia
      ClienteGV.latido(c2, 0) ##Espera
      primario_no_confirma_vista(c3,c1,c2, 2, ServidorGV.latidos_fallidos() * 2) ##El primario no va a confirmar

      comprobar_nopromocion(c3,c1,c2,2) ##Se comprueba que, tras la caida que ha habido del primario, no ha habido ninguna promocionado
                                        ## C1 sigue como primario, C1 sigue como copia
      IO.puts(" ... Superado")
    end

    ## Test 9 : Si anteriores servidores caen (Primario  y Copia),
    ##       un nuevo servidor sin inicializar no puede convertirse en primario.
    # sin_inicializar_no(C1, C2, C3),
    @tag :deshabilitado
    test "Sin inicializar, no entra como primario", %{c1: c1, c2: c2, c3: c3} do

      ClienteGV.latido(c1, 0) ##Primario
      ClienteGV.latido(c2, 0) ##Copia

      confirmar_vista(c1,2) ##Confirmamos la nueva vista
      espera_caida_primario_copia(c1,c2, 2, ServidorGV.latidos_fallidos() * 3) ##Una vez confirmada, se cae el primario
      ClienteGV.latido(c3, 0) ##El nuevo nodo entra
      comprobar_noinicializacion(c3) ##Hay que comprobar, que c3 no ha entrado como primario

      IO.puts(" ... Superado")
    end


    # ------------------ FUNCIONES DE APOYO A TESTS ------------------------

    defp confirmar_vista(nodo_primario, num_vista) do
      ClienteGV.latido(nodo_primario, num_vista) ##Se ha confirmado
    end

    defp espera_caida_primario_copia(_nodo_primario,_nodo_copia, _num_vista, 0), do: :fin
    defp espera_caida_primario_copia(nodo_primario,nodo_copia, num_vista, x) do
      Process.sleep(ServidorGV.intervalo_latidos())
      espera_caida_primario_copia(nodo_primario,nodo_copia, num_vista, x-1)
    end

    defp comprobar_noinicializacion(nodo_primario) do
      {vista,_} = ClienteGV.obten_vista(nodo_primario)
      assert vista.primario != nodo_primario
    end

    defp startServidores(maquinas) do
        tiempo_antes = :os.system_time(:milli_seconds)
        # Poner en marcha nodos servidor gestor de vistas y clientes
        # startNodos(%{tipoNodo: %{maquina: list(nombres)}})
        numMaquinas = length(maquinas)
        sv = ServidorGV.startNodo("sv", Enum.at(maquinas, 0))
        clientes = for i <- 1..3 do
                       if numMaquinas == 4 do
                           ClienteGV.startNodo("c" <> Integer.to_string(i),
                                               Enum.at(maquinas, i))
                       else # solo una máquina : la máquina local
                           ClienteGV.startNodo("c" <> Integer.to_string(i),
                                               Enum.at(maquinas, 0))
                       end
                   end

        # Poner en marcha servicios de cada uno
        # startServices(%{tipo: [nodos]})
        ServidorGV.startService(sv)
        c1 = ClienteGV.startService(Enum.at(clientes,0), sv)
        c2 = ClienteGV.startService(Enum.at(clientes,1), sv)
        c3 = ClienteGV.startService(Enum.at(clientes,2), sv)

        #Tiempo de puesta en marcha de nodos
        t_total = :os.system_time(:milli_seconds) - tiempo_antes
        IO.puts("Tiempo puesta en marcha de nodos  : #{t_total}")

        [sv: sv, c1: c1, c2: c2, c3: c3]
    end

    defp stopServidores(servidores, maquinas) do
        IO.puts "Finalmente eliminamos nodos"
        Enum.each(servidores, fn ({ _ , nodo}) -> NodoRemoto.stop(nodo) end)

        # Eliminar epmd en cada maquina con nodos Elixir
        Enum.each(maquinas, fn(m) -> NodoRemoto.killEpmd(m) end)
    end

    defp primer_primario(_c, 0), do: :fin
    defp primer_primario(c, x) do

        {vista, _} = ClienteGV.latido(c, 0)
        if vista.primario != c do
            Process.sleep(ServidorGV.intervalo_latidos())
            primer_primario(c, x - 1)
        end
    end

    defp primer_nodo_copia(_c1, _c2, 0), do: :fin
    defp primer_nodo_copia(c1, c2, x) do

        # el primario : != 0 para no dar por nuevo y < 0 para no validar
        ClienteGV.latido(c1, -1)
        {vista, _} = ClienteGV.latido(c2, 0)

        if vista.copia != c2 do
            Process.sleep(ServidorGV.intervalo_latidos())
            primer_nodo_copia(c1, c2, x - 1)
        end
    end

    def copia_releva_primario( _, _num_vista_inicial, 0), do: :fin
    def copia_releva_primario(c2, num_vista_inicial, x) do

        {vista, _} = ClienteGV.latido(c2, num_vista_inicial)

        if (vista.primario != c2) or (vista.copia != :undefined) do
            Process.sleep(ServidorGV.intervalo_latidos())
            copia_releva_primario(c2, num_vista_inicial, x - 1)
        end
    end

    defp servidor_rearranca_a_copia(_c1, _c2, _num_vista_valida, 0), do: :fin
    defp servidor_rearranca_a_copia(c1, c2, num_vista_valida, x) do

        ClienteGV.latido(c1, 0)
        {vista, _} = ClienteGV.latido(c2, num_vista_valida)

        if vista.copia != c1 do
            Process.sleep(ServidorGV.intervalo_latidos())
            servidor_rearranca_a_copia(c1, c2, num_vista_valida, x - 1)
        end
    end

    defp espera_pasa_a_copia(_c1, _c3, _num_vista_valida, 0), do: :fin
    defp espera_pasa_a_copia(c1, c3, num_vista_valida, x) do

        ClienteGV.latido(c3, num_vista_valida)
        {vista, _} = ClienteGV.latido(c1, num_vista_valida)

        if (vista.primario != c1) or (vista.copia != c3) do
            Process.sleep(ServidorGV.intervalo_latidos())
            espera_pasa_a_copia(c1, c3, num_vista_valida, x - 1)
        end
    end

    defp rearrancado_caido(c1, c3, num_vista_valida) do
      {vista, _} = ClienteGV.latido(c1, num_vista_valida)

      if(vista.primario == c1 && vista.copia == c3) do
        nil
      else
        :fin
      end
    end

    defp primario_no_confirma_vista(_c3,_c1,_c2, _num_vista_valida, 0), do: :fin
    defp primario_no_confirma_vista(c3,c1,c2, num_vista_valida, x) do
      {vista, _} = ClienteGV.latido(c1, num_vista_valida) ##La copia confirma pero no el primario
      ClienteGV.latido(c2, num_vista_valida) ##La espera confirma pero no el primario
      Process.sleep(ServidorGV.intervalo_latidos())
      primario_no_confirma_vista(c3,c1,c2,vista.num_vista,x-1)
    end

    defp comprobar_tentativa(nodo_cliente, nodo_primario, nodo_copia, n_vista) do
        # Solo interesa vista tentativa
        {vista, _} = ClienteGV.latido(nodo_cliente, -1)

        comprobar(nodo_primario, nodo_copia, n_vista, vista)
    end


    defp comprobar_valida(nodo_cliente, nodo_primario, nodo_copia, n_vista) do
        {vista, _ } = ClienteGV.obten_vista(nodo_cliente)

        comprobar(nodo_primario, nodo_copia, n_vista, vista)

        assert ClienteGV.primario(nodo_cliente) == nodo_primario
    end


    defp comprobar(nodo_primario, nodo_copia, n_vista, vista) do
        assert vista.primario == nodo_primario

        assert vista.copia == nodo_copia

        assert vista.num_vista == n_vista
    end

    defp comprobar_nopromocion(nodo_primarioCaido,nodo_copia,nodo_enEspera,num_vista) do
      {vista, _} = ClienteGV.obten_vista(nodo_copia)

      assert vista.primario != nodo_copia ##Comprobar que nodo copia no ha sido promocionado a primario

      assert vista.copia != nodo_enEspera ##Comprobar que nodo espera no ha sido promocionado a copia

      assert vista.primario == nodo_primarioCaido ##No ha cambiado nada, deberia de seguir
    end


end

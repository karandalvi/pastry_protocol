defmodule PastryProtocol do

  def main(input) do
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    IO.puts "Nodes   : #{numNodes}"
    IO.puts "Requests: #{numRequests}"
    nodeList = start(numNodes, [], [])
    send self, {:getStats}
    loop(nodeList, numNodes, numRequests, [], 0, 0)
  end

  def start(numNodes, nodeList, pidList) when numNodes > 0 do
    newNode = :crypto.hash(:md5, Integer.to_string(numNodes)) |> Base.encode16()
    newPid = spawn(PNode, :init, [newNode])
    send newPid, {:console, self}
    if length(pidList) > 0 do
      # send newPid, {:join, Enum.at(pidList, round(:math.floor(:rand.uniform() * length(pidList))))}
      send newPid, {:join, Enum.at(pidList, 0)}
    end
    nodeList = nodeList ++ [newNode]
    pidList = pidList ++ [newPid]
    start(numNodes-1, nodeList, pidList)
  end

  def start(numNodes, nodeList, pidList) when numNodes <= 0 do
    [nodeList, pidList]
  end

  def loop(nodeList, numNodes, numRequests, hops, sum, lastMessage) do
    receive do
      {:getStats} ->
        nameList = Enum.at(nodeList, 0)
        pidList = Enum.at(nodeList, 1)
        :timer.sleep(8000) #TODO: 8000 
        for y <- 1..numRequests do
          for x <- Enum.at(nodeList, 1) do
            send x, {:print}
            r = round(:math.floor(:rand.uniform() * length(pidList)))
            send x, {:sendRequest, Enum.at(pidList, r), Enum.at(nameList, r)}
          end
        end
        loop(nodeList, numNodes, numRequests, hops, sum, lastMessage)

      {:collectHopNumber, hopCount} ->
        hops = hops ++ [hopCount]
        sum = sum + hopCount
        IO.puts "Running..."
        lastMessage = :os.system_time(:millisecond)
        :timer.sleep(4000)
        send self, {:check}
        loop(nodeList, numNodes, numRequests, hops, sum, lastMessage)

      {:check} ->
        if :os.system_time(:millisecond) - lastMessage > 4000 do
          send self, {:exit}
        end
        send self, {:collectHopNumber, }
        loop(nodeList, numNodes, numRequests, hops, sum, lastMessage)

        {:exit} ->
          IO.puts "Hop Average: #{sum / length(hops)}"
          IO.puts "Exiting Program"
    end
  end
end

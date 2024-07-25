import Foundation


class PointSender {
    private var shouldStop = false
    private var url: URL
    private var points: [Point3D];

    init(url: URL) {
        self.url = url
        self.points = [];
    }

    func stop() {
        shouldStop = true
    }
    
    func start(){
        shouldStop = false;
    }
    
    func setUrl (url: URL){
        self.url = url;
    }
    
    func addPoint(point: Point3D){
        points.append(point);
    }
    

    func startSendingPoints(interval: Float) async {
        

        

        while !shouldStop {
            await sendPoints()
            await Task.sleep(UInt64(interval * 1_000_000_000))  // Sleep for 5 seconds
        }
    }

    private func sendPoints() async {
        print("send points")
        if self.points.isEmpty{
            print("no points")
            return
            
        }
        do {
            // Convert the JSON object to data
            print ("\(self.points.count) points")
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(self.points) {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                
                let (data, _) = try await URLSession.shared.data(for: request)
                self.points.removeAll()
                let str = String(data: data, encoding: .utf8)
                print("Received data:\n\(str ?? "")")
            }
            
            // Create a URL request
            
        } catch {
            print("Error: \(error)")
        }
    }
}

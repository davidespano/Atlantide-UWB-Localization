//
//  AngleDistanceView.swift
//  uwbtestapp
//
//  Created by Davide Spano on 25/07/24.
//

import SwiftUI
import EstimoteUWB

struct AngleDistanceView: View {
    let uwb = AngleDistanceUWBManager()
    
    @State var ip = "192.168.1.174:5000"
    
    
    
    @State var  points: [Point3D] = Array(repeating: Point3D(x: 0.0, y: 0.0, z: 0.0, guuid: "none", sensed: false), count: 9)
    @State private var connectButtonText = "Connect to Beacons"
    
    let pointSender = PointSender(url: URL(string: "http://localhost")!);
    
    var body: some View {
        VStack {
            Form {
               
                Text("Connection")
                    .font(.title)
                
                TextField("Enter text here", text: $ip)
                                .padding()
                                .border(Color.gray, width: 0.5)
                
                    Button(action: {
                        if connectButtonText == "Connect to Beacons"{
                            uwb.connectUWB()
                            
                            pointSender.setUrl(url: URL(string: "http:\(ip)/updatePosition")!)
                            pointSender.start()
                            
                            Task {
                                await pointSender.startSendingPoints(interval: 0.5)
                            }
                        
                            connectButtonText = "Disconnect from Beacons"
                        }else {
                            connectButtonText = "Connect to Beacons"
                            uwb.disconnectUWB();
                            pointSender.stop()
                        }
                            }) {
                                
                                Text(connectButtonText)
                            }.buttonStyle(.borderedProminent)
                
                
                
                
            
                Text("Sensed Distances")
                    .font(.title)
                Label("Beacon 1: \(points[0].toString())", systemImage: "bookmark.fill").foregroundColor(.primary)
                Label("Beacon 2: \(points[1].toString())", systemImage: "bookmark.fill").foregroundColor(.yellow)
                Label("Beacon 3: \(points[2].toString())", systemImage: "bookmark.fill").foregroundColor(.brown)
                
            }
           
            
            
        }
        .padding()
        .onDisappear(){
            uwb.terminateUWB();
        }
        .onAppear(){
            uwb.setContent(c: self)
        }
        
    }
    
    
    
    public func setPosition(id: Int, x: Float, y: Float, z: Float, guuid: String, sensed: Bool){
        points[id].x = x;
        points[id].y = y;
        points[id].z = z;
        points[id].guuid = guuid;
        points[id].sensed = sensed;
        
        pointSender.addPoint(point: Point3D(x: x, y: y, z: z, guuid: guuid, sensed: sensed))
    }
    
}

struct AngleDistanceView_Preview: PreviewProvider {
    static var previews: some View {
        AngleDistanceView()
    }
}

class AngleDistanceUWBManager: NSObject, ObservableObject {
    private var c: AngleDistanceView?
    private var idDictionary = [
        "6264e0ba93e0aefb58e62306457a4f04": 0,
        "f3a75c3a8c335c1378f45c2a90870719": 1,
        "670e132e4968c72afdd1084ddc65ef16": 2
    ]
    
    private var uwbManager: EstimoteUWBManager?
    private var beacons: [UWBIdentifiable] = []

    override init() {
        super.init()
        setupUWB()
    }

    
    public func setContent(c:AngleDistanceView){
        self.c = c;
    }
    
    public func setupUWB() {
            uwbManager = EstimoteUWBManager(delegate: self,
                                            options: EstimoteUWBOptions(shouldHandleConnectivity: false,
                                                                        isCameraAssisted: false))
        
    }
    
    public func connectUWB(){
        uwbManager?.startScanning()
        
        
    }
    
    public func disconnectUWB(){
        uwbManager?.stopScanning()
        for device in beacons{
            uwbManager?.disconnect(from: device)
        }
        beacons.removeAll()
    }
    
    public func terminateUWB(){
        for device in beacons{
            uwbManager?.disconnect(from: device)
        }
    }
    
    
}

// REQUIRED PROTOCOL
extension AngleDistanceUWBManager: EstimoteUWBManagerDelegate {
    
    func didUpdatePosition(for device: EstimoteUWBDevice) {
        //print("position updated for device: \(device.publicIdentifier) : \(device.distance)")
        let i = idDictionary[device.publicIdentifier]
        if let vector = device.vector
        {
            c?.setPosition(
                id: i!,
                x: vector.x * device.distance,
                y: vector.y * device.distance,
                z: vector.z * device.distance,
                guuid: device.publicIdentifier,
                sensed: true
                )
        }
                
    
        
    }
    
    // OPTIONAL
    func didDiscover(device: UWBIdentifiable, with rssi: NSNumber, from manager: EstimoteUWBManager) {
        //print("Discovered Device: \(device.publicIdentifier) rssi: \(rssi)")
        // if shouldHandleConnectivity is set to true - then you could call manager.connect(to: device)
        // additionally you can globally call discoonect from the scope where you have inititated EstimoteUWBManager -> disconnect(from: device) or disconnect(from: publicId)
        if idDictionary.keys.contains(device.publicIdentifier){
            beacons.append(device)
            manager.connect(to: device)
        }
        
        
    }
    
    // OPTIONAL
    func didConnect(to device: UWBIdentifiable) {
        //print("Successfully Connected to: \(device.publicIdentifier)")
    }
    
    // OPTIONAL
    func didDisconnect(from device: UWBIdentifiable, error: Error?) {
        //print("Disconnected from device: \(device.publicIdentifier)- error: \(String(describing: error))")
    }
    
    // OPTIONAL
    func didFailToConnect(to device: UWBIdentifiable, error: Error?) {
        //print("Failed to conenct to: \(device.publicIdentifier) - error: \(String(describing: error))")
    }

    // OPTIONAL PROTOCOL FOR BEACON BLE RANGING
//    func didRange(for beacon: EstimoteBLEDevice) {
//        print("beacon did range: \(beacon)")
//    }
}

struct Point3D : Codable{
    var x: Float
    var y: Float
    var z: Float
    
    var guuid: String
    var sensed: Bool
    
    func toString() -> String {
        return String(format: "(%.2f, %.2f, %.2f)", x, y, z)
    }
}




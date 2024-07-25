//
//  ContentView.swift
//  uwbtestapp
//
//  Created by DJ HAYDEN on 1/14/22.
//

import SwiftUI
import EstimoteUWB

struct SimpleTrilaterationView: View {
    let uwb = TrilaterationUWBManager()
    @State var x2:Float = 330;
    @State var x3:Float = 165;
    @State var y3:Float = 198;
    @State var x2t = "330";
    @State var x3t = "165";
    @State var y3t = "198";
    
    @State var d:[Float] = [0.0, 0.0, 0.0]
    @State var pos:[Float] = [0.0, 0.0, 0.0]
    @State private var connectButtonText = "Connect to Beacons"
    
    var body: some View {
        VStack {
            Form {
                Text("Trilateration Settings")
                    .font(.title)
                HStack{
                    Label("x2", systemImage: "bookmark.fill").foregroundColor(.yellow)
                     TextField("x2 value", text: $x2t)
                        .keyboardType(.numbersAndPunctuation)
                     Text("cm")
                 }
                HStack{
                     Label("x3", systemImage: "bookmark.fill").foregroundColor(.brown)
                     TextField("x3 value", text: $x3t)
                        .keyboardType(.numbersAndPunctuation)
                     Text("cm")
                 }
                HStack{
                     Label("y3", systemImage: "bookmark.fill").foregroundColor(.brown)
                     TextField("y3 value", text: $y3t)
                        .keyboardType(.numbersAndPunctuation)
                     Text("cm")
                 }
                HStack{
                    Spacer()
                    Button(action: {
                        if connectButtonText == "Connect to Beacons"{
                            uwb.connectUWB()
                            x2 = Float(x2t)!
                            x3 = Float(x3t)!
                            y3 = Float(y3t)!
                        
                            connectButtonText = "Disconnect from Beacons"
                        }else {
                            connectButtonText = "Connect to Beacons"
                            uwb.disconnectUWB();
                        }
                            }) {
                                
                                Text(connectButtonText)
                            }.buttonStyle(.borderedProminent)
                    Spacer()
                }
                
                
            }
            Form{
                Text("Sensed Distances")
                    .font(.title)
                Label("Beacon 1: \(d[0])", systemImage: "bookmark.fill").foregroundColor(.primary)
                Label("Beacon 2: \(d[1])", systemImage: "bookmark.fill").foregroundColor(.yellow)
                Label("Beacon 3: \(d[2])", systemImage: "bookmark.fill").foregroundColor(.brown)
                Label("Trilateration: (\(String(format: "%.0f", pos[0])), \(String(format: "%.0f", pos[1])), \(String(format: "%.0f", pos[2])))", systemImage: "triangle")
                
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
    
    public func setDistance(index: Int, distance: Float){
        if (0...2).contains(index){
            d[index] = distance * 100;
        }
    }
    
    public func setPosition(x: Float, y: Float, z: Float){
        pos[0] = x
        pos[1] = y
        pos[2] = z
    }
    
}

struct SimpleTrilaterationView_Preview: PreviewProvider {
    static var previews: some View {
        SimpleTrilaterationView()
    }
}

class TrilaterationUWBManager: NSObject, ObservableObject {
    private var c: SimpleTrilaterationView?
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

    
    public func setContent(c:SimpleTrilaterationView){
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
extension TrilaterationUWBManager: EstimoteUWBManagerDelegate {
    
    func didUpdatePosition(for device: EstimoteUWBDevice) {
        print("position updated for device: \(device.publicIdentifier) : \(device.distance)")
        let i = idDictionary[device.publicIdentifier]
        c?.setDistance(index: i!, distance: device.distance)
        
        let d0sq = c!.d[0] * c!.d[0]
        let d1sq = c!.d[1] * c!.d[1]
        let d2sq = c!.d[2] * c!.d[2]
        
        let x2sq = c!.x2 * c!.x2
        let x3sq = c!.x3 * c!.x3
        let y3sq = c!.y3 * c!.y3
        
        let x = (d0sq - d1sq + x2sq)/(2 * c!.x2)
        let y = (d0sq - d2sq + x3sq + y3sq - (2 * c!.x3 * x))/(2 * c!.y3)
        let z = sqrt(abs(d0sq - x * x - y * y))
        
        c!.setPosition(x: x, y: y, z: z)
    }
    
    // OPTIONAL
    func didDiscover(device: UWBIdentifiable, with rssi: NSNumber, from manager: EstimoteUWBManager) {
        print("Discovered Device: \(device.publicIdentifier) rssi: \(rssi)")
        // if shouldHandleConnectivity is set to true - then you could call manager.connect(to: device)
        // additionally you can globally call discoonect from the scope where you have inititated EstimoteUWBManager -> disconnect(from: device) or disconnect(from: publicId)
        beacons.append(device)
        manager.connect(to: device)
        
    }
    
    // OPTIONAL
    func didConnect(to device: UWBIdentifiable) {
        print("Successfully Connected to: \(device.publicIdentifier)")
    }
    
    // OPTIONAL
    func didDisconnect(from device: UWBIdentifiable, error: Error?) {
        print("Disconnected from device: \(device.publicIdentifier)- error: \(String(describing: error))")
    }
    
    // OPTIONAL
    func didFailToConnect(to device: UWBIdentifiable, error: Error?) {
        print("Failed to conenct to: \(device.publicIdentifier) - error: \(String(describing: error))")
    }

    // OPTIONAL PROTOCOL FOR BEACON BLE RANGING
//    func didRange(for beacon: EstimoteBLEDevice) {
//        print("beacon did range: \(beacon)")
//    }
}



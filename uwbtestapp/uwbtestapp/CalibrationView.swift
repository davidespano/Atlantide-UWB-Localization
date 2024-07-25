//
//  CalibrationView.swift
//  uwbtestapp
//
//  Created by Davide Spano on 20/10/23.
//
import SwiftUI
import EstimoteUWB

struct CalibrationView: View {
    let uwb = CalibrationUWBManager()
    @State var x2t = "330";
    @State var x3t = "165";
    @State var y3t = "330";
    @State var x4t = "165";
    @State var y4t = "165";
    
    @State var gtx = "0";
    @State var gty = "0";
    
    @State var recording = false;
    @State var fileURL = URL(string: "");
    @State var fileHandle: FileHandle = FileHandle.standardError;
    
    
    
    @State var d:[Float] = [0.0, 0.0, 0.0, 0.0]
    
    @State private var connectButtonText = "Connect to Beacons"
    @State private var recordButtonText = "Record"
    
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
            }
            Form {
                Text("Ground Truth")
                    .font(.title)
                HStack{
                    Label("x", systemImage: "mappin.and.ellipse").foregroundColor(.accentColor)
                    TextField("x value", text: $gtx)
                        .keyboardType(.numbersAndPunctuation)
                    Text("cm")
                }
                HStack{
                    Label("y", systemImage: "mappin.and.ellipse").foregroundColor(.accentColor)
                    TextField("y value", text: $gty)
                        .keyboardType(.numbersAndPunctuation)
                    Text("cm")
                }
                HStack{
                    Spacer()
                    Button(action: {
                        if recording {
                            recordButtonText = "Record"
                            recording = false;
                            stopRecording();
                        }else {
                            recordButtonText = "Stop"
                            recording = true;
                            startRecording();
                        }
                    }) {
                        
                        Text(recordButtonText)
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
                HStack{
                    Spacer()
                    Button(action: {
                        if connectButtonText == "Connect to Beacons"{
                            uwb.connectUWB()
                            
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
            
            
            
            
        }
        .padding()
        .onDisappear(){
            uwb.terminateUWB();
        }
        .onAppear(){
            uwb.setContent(c: self)
            
        }
        
    }
    
    
    private func startRecording(){
        let fileManager = FileManager.default
        do {
            let path = try fileManager.url(for: .documentDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
            let fileURL = path.appendingPathComponent("session-\(Int64(NSDate().timeIntervalSince1970 * 1000)).csv")
            let titles = "time, gt_x, gt_y, pos1_x, pos1_y, pos2_x, pos_2y, pos3_x, pos3y, pos4_x, pos4_y, d1, d2, d3, d4\n"
            try titles.write(to: fileURL, atomically: true, encoding: .utf8)
            
            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
        } catch {
            print("error creating file: \(error)")
        }
    }
    
    private func stopRecording(){
        do {
            try fileHandle.close();
        }catch {
            print("error closing file: \(error)")
        }
    }
    
    
    public func setDistance(index: Int, distance: Float){
        if (0...3).contains(index){
            d[index] = distance * 100;
        }
        
        if recording{
            do{
                let value = "\(Int64(NSDate().timeIntervalSince1970 * 1000000)), \(Float(gtx)!), \(Float(gty)!), 0.0, 0.0, 0.0, \(Float(x2t)!), \(Float(x3t)!), \(Float(y3t)!), \(Float(x4t)!), \(Float(y4t)!), \(d[0]), \(d[1]), \(d[2]), \(d[3]) \n"
                
                try fileHandle.write(contentsOf: value.data(using: .utf8)!)
            }catch{
                print("error in writing file \(error)")
            }
        }
        
    }
    
    public func setPosition(x: Float, y: Float, z: Float){
        //pos[0] = x
        //pos[1] = y
        //pos[2] = z
    }
    
}

struct CalibrationView_Previews: PreviewProvider {
    static var previews: some View {
        CalibrationView()
    }
}

//
//  AtlantideUWBManager.swift
//  uwbtestapp
//
//  Created by Davide Spano on 20/10/23.
//
import EstimoteUWB

class CalibrationUWBManager:
    NSObject, ObservableObject {
    private var c: CalibrationView?
    private var idDictionary = [
        "6264e0ba93e0aefb58e62306457a4f04": 0,
        "f3a75c3a8c335c1378f45c2a90870719": 1,
        "670e132e4968c72afdd1084ddc65ef16": 2,
        "43a577c5f32b88d1a5d4e547a7fd5400": 3
    ]
    
    private var uwbManager: EstimoteUWBManager?
    private var beacons: [UWBIdentifiable] = []
    
    override init() {
        super.init()
        setupUWB()
    }
    
    
    public func setContent(c:CalibrationView){
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

extension CalibrationUWBManager:
    EstimoteUWBManagerDelegate {
    
    func didUpdatePosition(for device: EstimoteUWBDevice) {
        print("position updated for device: \(device.publicIdentifier) : \(device.distance)")
        let i = idDictionary[device.publicIdentifier]
        c?.setDistance(index: i!, distance: device.distance)
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


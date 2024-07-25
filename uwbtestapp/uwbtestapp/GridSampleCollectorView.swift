//
//  GridSampleCollectorView.swift
//  uwbtestapp
//
//  Created by Davide Spano on 27/10/23.
//

import SwiftUI
import EstimoteUWB

struct GridSampleCollectorView: View {
    let uwb = GridUWBManager()
    let flush = 1024;
    @State var samples = String();
    @State var pointCount = 0;
    
    @State var gtx = 0;
    @State var gty = 0;
    
    @State var recording = false;
    @State var fileURL = URL(string: "");
    @State var fileHandle: FileHandle = FileHandle.standardError;
    
    
    
    @State var d:[Float] = [0.0, 0.0, 0.0, 0.0]
    
    @State private var connectButtonText = "Connect to Beacons"
    @State private var recordButtonText = "Record"
    
    var body: some View {
        
        Form {
            
            Text("Sensed Distances")
                .font(.title)
            Label("Beacon 1: \(d[0])", systemImage: "bookmark.fill").foregroundColor(.primary)
            Label("Beacon 2: \(d[1])", systemImage: "bookmark.fill").foregroundColor(.yellow)
            Label("Beacon 3: \(d[2])", systemImage: "bookmark.fill").foregroundColor(.brown)
            Label("Beacon 4: \(d[3])", systemImage: "bookmark.fill").foregroundColor(.primary)
            
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
            
            Spacer()
            Text("Ground Truth")
                .font(.title)
            HStack{
                Label("Row \t", systemImage: "mappin.and.ellipse").foregroundColor(.accentColor)
                Stepper("\(gty)", value: $gty, in: 0...100)
            }
            HStack{
                Label("Col \t", systemImage: "mappin.and.ellipse").foregroundColor(.accentColor)
                Stepper("\(gtx)", value: $gtx, in: 0...100)
            }
            
            Text("Collected samples \(pointCount)")
           
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
            let fileURL = path.appendingPathComponent("cell-\(gty)_\(gtx)-\(Int64(NSDate().timeIntervalSince1970 * 1000)).csv")
            let titles = "time, row, col, d1, d2, d3, d4\n"
            try titles.write(to: fileURL, atomically: true, encoding: .utf8)
            
            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle.seekToEnd()
        } catch {
            print("error creating file: \(error)")
        }
    }
    
    private func stopRecording(){
        if pointCount > 0{
            flushSampleBuffer();
        }
        
        do {
            try fileHandle.close();
        }catch {
            print("error closing file: \(error)")
        }
    }
    
    public func setDistance(index: Int, distance: Float){
        if (0...3).contains(index) && d[index] != distance * 100{
            d[index] = distance * 100;
            
            if recording{
                samples.append("\(Int64(NSDate().timeIntervalSince1970 * 1000000)), \(gty), \(gtx),\(d[0]), \(d[1]), \(d[2]), \(d[3]) \n")
                pointCount+=1;
                
                if pointCount == flush{
                    flushSampleBuffer();
                }
            }
        }
        
        
        
    }
    
    
    private func flushSampleBuffer(){
        do{
            pointCount = 0;
            try fileHandle.write(contentsOf: samples.data(using: .utf8)!)
            samples.removeAll()
        }catch{
            print("error in writing file \(error)")
        }
    }
}

struct GridSampleCollectorView_Previews: PreviewProvider {
    static var previews: some View {
        GridSampleCollectorView()
    }
}

class GridUWBManager:
    NSObject, ObservableObject {
    private var c: GridSampleCollectorView?
    private var idDictionary = [
        "6264e0ba93e0aefb58e62306457a4f04": 0,
        "0cc6444b70a27ce511338675efbea110": 1,
        //"f3a75c3a8c335c1378f45c2a90870719": 1,
        "670e132e4968c72afdd1084ddc65ef16": 2,
        "43a577c5f32b88d1a5d4e547a7fd5400": 3
    ]
    
    private var uwbManager: EstimoteUWBManager?
    private var beacons: [UWBIdentifiable] = []
    
    override init() {
        super.init()
        setupUWB()
    }
    
    
    public func setContent(c:GridSampleCollectorView){
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

extension GridUWBManager:
    EstimoteUWBManagerDelegate {
    
    func didUpdatePosition(for device: EstimoteUWBDevice) {
        //print("position updated for device: \(device.publicIdentifier) : \(device.distance)")
        let i = idDictionary[device.publicIdentifier]
        c?.setDistance(index: i!, distance: device.distance)
           
        
        
    }
    
    // OPTIONAL
    func didDiscover(device: UWBIdentifiable, with rssi: NSNumber, from manager: EstimoteUWBManager) {
        //print("Discovered Device: \(device.publicIdentifier) rssi: \(rssi)")
        // if shouldHandleConnectivity is set to true - then you could call manager.connect(to: device)
        // additionally you can globally call discoonect from the scope where you have inititated EstimoteUWBManager -> disconnect(from: device) or disconnect(from: publicId)
        if(idDictionary.keys.contains(device.publicIdentifier)){
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

//
//  HubManager.swift
//  BoostBLEKit-Showcase
//
//  Created by Shinichiro Oba on 10/07/2018.
//  Copyright © 2018 bricklife.com. All rights reserved.
//

import Foundation
import BoostBLEKit
import CoreBluetooth

struct MoveHubService {
    
    static let serviceUuid = CBUUID(string: GATT.serviceUuid)
    static let characteristicUuid = CBUUID(string: GATT.characteristicUuid)
}

protocol HubManagerDelegate: class {
    
    func didConnect(peripheral: CBPeripheral)
    func didFailToConnect(peripheral: CBPeripheral, error: Error?)
    func didDisconnect(peripheral: CBPeripheral, error: Error?)
    func didUpdate(notification: BoostBLEKit.Notification)
}

class HubManager: NSObject {
    
    weak var delegate: HubManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    
    var connectedHub: Hub?
    var isInitializingHub = false
    var sensorValues: [PortId: Data] = [:]
    
    var isConnectedHub: Bool {
        return peripheral != nil
    }
    
    init(delegate: HubManagerDelegate) {
        super.init()
        
        self.delegate = delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [MoveHubService.serviceUuid], options: nil)
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    private func connect(peripheral: CBPeripheral, advertisementData: [String : Any]) {
        guard self.peripheral == nil else { return }
        
        guard let manufacturerData = advertisementData["kCBAdvDataManufacturerData"] as? Data else { return }
        guard let hubType = HubType(manufacturerData: manufacturerData) else { return }
        
        switch hubType {
        case .boost:
            self.connectedHub = Boost.MoveHub()
        case .boostV1:
            self.connectedHub = Boost.MoveHubV1()
        case .poweredUp:
            self.connectedHub = PoweredUp.SmartHub()
        case .duploTrain:
            self.connectedHub = Duplo.TrainBase()
        case .controlPlus:
            self.connectedHub = ControlPlus.SmartHub()
        case .remoteControl:
            self.connectedHub = PoweredUp.RemoteControl()
        }
        
        self.isInitializingHub = true
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
            self.characteristic = nil
            self.connectedHub = nil
            self.isInitializingHub = false
        }
    }
    
    private func set(characteristic: CBCharacteristic) {
        if let peripheral = peripheral, characteristic.properties.contains([.write, .notify]) {
            self.characteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    private func receive(notification: BoostBLEKit.Notification) {
        print(notification)
        switch notification {
        case .hubProperty:
            break
            
        case .connected(let portId, let ioType):
            connectedHub?.connectedIOs[portId] = ioType
            if let command = connectedHub?.subscribeCommand(portId: portId) {
                write(data: command.data)
            }
            
        case .disconnected(let portId):
            connectedHub?.connectedIOs[portId] = nil
            sensorValues[portId] = nil
            if let command = connectedHub?.unsubscribeCommand(portId: portId) {
                write(data: command.data)
            }
            
        case .sensorValue(let portId, let value):
            sensorValues[portId] = value
        }
        
        if isInitializingHub {
            isInitializingHub = false
            write(data: HubPropertiesCommand(property: .advertisingName, operation: .enableUpdates).data)
            write(data: HubPropertiesCommand(property: .firmwareVersion, operation: .requestUpdate).data)
            write(data: HubPropertiesCommand(property: .batteryVoltage, operation: .enableUpdates).data)
        }
    }
    
    func write(data: Data) {
        print("<W", data.hexString)
        if let peripheral = peripheral, let characteristic = characteristic {
            DispatchQueue.main.async {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            }
        }
    }
}

extension HubManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauthorized")
        case .poweredOff:
            print("poweredOff")
        case .poweredOn:
            print("poweredOn")
        @unknown default:
            print("@unknown default")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(#function, peripheral)
        print("RSSI:", RSSI)
        print("advertisementData:", advertisementData)
        connect(peripheral: peripheral, advertisementData: advertisementData)
        stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([MoveHubService.serviceUuid])
        delegate?.didConnect(peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(#function, peripheral, error)
        }
        delegate?.didFailToConnect(peripheral: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(#function, peripheral, error)
        }
        delegate?.didDisconnect(peripheral: peripheral, error: error)
    }
}

extension HubManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == MoveHubService.serviceUuid }) {
            peripheral.discoverCharacteristics([MoveHubService.characteristicUuid], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == MoveHubService.characteristicUuid }) {
            set(characteristic: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        print(">N", data.hexString)
        if let notification = Notification(data: data) {
            receive(notification: notification)
            delegate?.didUpdate(notification: notification)
        }
    }
}

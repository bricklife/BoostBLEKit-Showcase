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
    private var peripheral: [UUID: CBPeripheral] = [:]
    private var characteristic: [UUID: CBCharacteristic] = [:]
    
    var connectedHub: [UUID: Hub] = [:]
    var isInitializingHub: [UUID: Bool] = [:]
    var sensorValues: [PortId: Data] = [:]
    
    var isConnectedHub: Bool {
        return peripheral.count > 0
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
        guard self.peripheral[peripheral.identifier] == nil else { return }
        
        guard let manufacturerData = advertisementData["kCBAdvDataManufacturerData"] as? Data else { return }
        guard let hubType = HubType(manufacturerData: manufacturerData) else { return }
        
        switch hubType {
        case .boost:
            self.connectedHub[peripheral.identifier] = Boost.MoveHub()
        case .boostV1:
            self.connectedHub[peripheral.identifier] = Boost.MoveHubV1()
        case .poweredUp:
            self.connectedHub[peripheral.identifier] = PoweredUp.SmartHub()
        case .remoteControl:
            self.connectedHub[peripheral.identifier] = PoweredUp.RemoteControl()
        case .duploTrain:
            self.connectedHub[peripheral.identifier] = Duplo.TrainBase()
        case .controlPlus:
            self.connectedHub[peripheral.identifier] = ControlPlus.SmartHub()
        }
        
        self.isInitializingHub[peripheral.identifier] = true
        self.peripheral[peripheral.identifier] = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        stopScan()
        for uuid in peripheral.keys {
            guard let peripheral = peripheral[uuid] else { continue }
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    private func set(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        if characteristic.properties.contains([.write, .notify]) {
            self.characteristic[peripheral.identifier] = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    private func receive(peripheral: CBPeripheral, notification: BoostBLEKit.Notification) {
        print(notification)
        var connectedHub = self.connectedHub[peripheral.identifier]
        switch notification {
        case .hubProperty:
            break
            
        case .connected(let portId, let ioType):
            connectedHub?.connectedIOs[portId] = ioType
            if let command = connectedHub?.subscribeCommand(portId: portId) {
                write(peripheral: peripheral, data: command.data)
            }
            
        case .disconnected(let portId):
            connectedHub?.connectedIOs[portId] = nil
            sensorValues[portId] = nil
            if let command = connectedHub?.unsubscribeCommand(portId: portId) {
                write(peripheral: peripheral, data: command.data)
            }
            
        case .sensorValue(let portId, let value):
            sensorValues[portId] = value
        }
        
        if isInitializingHub[peripheral.identifier] == true {
            isInitializingHub[peripheral.identifier] = false
            write(peripheral: peripheral, data: HubPropertiesCommand(property: .advertisingName, operation: .enableUpdates).data)
            write(peripheral: peripheral, data: HubPropertiesCommand(property: .firmwareVersion, operation: .requestUpdate).data)
            write(peripheral: peripheral, data: HubPropertiesCommand(property: .batteryVoltage, operation: .enableUpdates).data)
        }
    }
    
    func write(peripheral: CBPeripheral, data: Data) {
        print("<W", data.hexString)
        if let characteristic = characteristic[peripheral.identifier] {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func write(uuid: UUID, data: Data) {
        if let peripheral = peripheral[uuid] {
            write(peripheral: peripheral, data: data)
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
//        stopScan()
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
        
        let uuid = peripheral.identifier
        self.connectedHub[uuid] = nil
        self.isInitializingHub[uuid] = false
        self.peripheral[uuid] = nil
        
        delegate?.didFailToConnect(peripheral: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(#function, peripheral, error)
        }
        
        let uuid = peripheral.identifier
        self.connectedHub[uuid] = nil
        self.isInitializingHub[uuid] = false
        self.peripheral[uuid] = nil
        self.characteristic[uuid] = nil
        
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
            set(peripheral: peripheral, characteristic: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        print(">N", data.hexString)
        if let notification = Notification(data: data) {
            receive(peripheral: peripheral, notification: notification)
            delegate?.didUpdate(notification: notification)
        }
    }
}

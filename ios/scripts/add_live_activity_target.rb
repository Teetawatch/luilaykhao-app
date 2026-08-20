#!/usr/bin/env ruby
# frozen_string_literal: true

# เพิ่มเป้าหมาย widget extension เข้า Runner.xcodeproj
#
# เป้าหมายนี้ถือของสองอย่างที่คนละหน้าจอกัน แต่เป็น widget extension ทั้งคู่:
#   - การ์ด "วันเดินทาง" บนหน้าจอล็อก (Live Activity)
#   - วิดเจ็ตนับถอยหลังบนหน้าโฮม (WidgetKit)
#
# ผลของสคริปต์นี้ถูก commit ไปกับ project.pbxproj แล้ว — ปกติจึงไม่ต้องรัน สิ่งที่มัน
# มีไว้เพื่อคือกรณีที่ไฟล์โปรเจ็กต์ถูกสร้างใหม่ (เช่นทำ `flutter create .` ทับ) แล้ว
# เป้าหมายหายไป และกรณีที่เพิ่มไฟล์ใหม่เข้าเป้าหมาย รันซ้ำได้เสมอ ไม่สร้างซ้ำซ้อน
#
#   ruby ios/scripts/add_live_activity_target.rb
#
# ต้องมี xcodeproj (มากับ CocoaPods อยู่แล้ว): gem install xcodeproj

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Runner.xcodeproj', __dir__)
TARGET_NAME = 'LiveActivityExtension'
GROUP_NAME = 'LiveActivity'
DEPLOYMENT_TARGET = '16.2'

# สะพาน Flutter ↔ native อยู่ในแอปหลักเท่านั้น ไม่ใช่ใน extension
RUNNER_ONLY_SOURCES = ['LiveActivityChannel.swift', 'HomeWidgetChannel.swift'].freeze

# ไฟล์ในกลุ่ม LiveActivity/ ที่ต้องอยู่ในทั้งสองเป้าหมาย — แอปเป็นฝ่ายเขียน วิดเจ็ต
# เป็นฝ่ายอ่าน ทั้งคู่ต้องใช้โครงสร้างและชื่อคีย์ตัวเดียวกันเป๊ะ
SHARED_SOURCES = ['TripActivityAttributes.swift', 'HomeWidgetSnapshot.swift'].freeze

EXTENSION_SOURCES = [
  'TripActivityAttributes.swift',
  'TripActivityWidget.swift',
  'HomeWidgetSnapshot.swift',
  'TripCountdownWidget.swift',
  'LiveActivityBundle.swift',
].freeze

XCCONFIG_NAME = 'LiveActivityExtension.xcconfig'
ENTITLEMENTS_NAME = 'LiveActivityExtension.entitlements'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'ไม่พบเป้าหมาย Runner'

# ไฟล์อยู่ในเป้าหมายนี้แล้วหรือยัง — เทียบด้วยชื่อไฟล์ ไม่ใช่ตัวอ้างอิง เพราะไฟล์
# เดียวกันอาจถูกอ้างจากหลายกลุ่ม
def member?(target, name)
  target.source_build_phase.files_references.any? { |f| f.path.to_s.end_with?(name) }
end

runner_group = project.main_group.find_subpath('Runner', true)
RUNNER_ONLY_SOURCES.each do |name|
  next if member?(runner, name)

  file = runner_group.find_file_by_path(name) || runner_group.new_file(name)
  runner.add_file_references([file])
  puts "เพิ่ม #{name} เข้าเป้าหมาย Runner แล้ว"
end

group = project.main_group.find_subpath(GROUP_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(GROUP_NAME)

extension_target = project.targets.find { |t| t.name == TARGET_NAME }
creating = extension_target.nil?

if creating
  base_bundle_id = runner.build_configurations
                         .map { |c| c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
                         .compact.first || 'com.luilaykhao.app'
  team = runner.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first

  extension_target = project.new_target(
    :app_extension,
    TARGET_NAME,
    :ios,
    DEPLOYMENT_TARGET,
    project.products_group,
    :swift
  )

  group.new_file('Info.plist') unless group.find_file_by_path('Info.plist')

  # เวอร์ชันของ extension ต้องมาจาก pubspec เหมือนตัวแอป — ดูเหตุผลใน xcconfig
  xcconfig = group.find_file_by_path(XCCONFIG_NAME) || group.new_file(XCCONFIG_NAME)

  extension_target.build_configurations.each do |config|
    config.base_configuration_reference = xcconfig
    settings = config.build_settings
    # ไม่มีสองบรรทัดนี้ ผลลัพธ์จะกลายเป็นไฟล์ชื่อ ".appex" เปล่า ๆ แล้ว Xcode ตีกลับ
    # ว่า "Multiple commands produce" เพราะทุก configuration ผลิตชื่อเดียวกัน
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['WRAPPER_EXTENSION'] = 'appex'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{base_bundle_id}.LiveActivity"
    settings['INFOPLIST_FILE'] = "#{GROUP_NAME}/Info.plist"
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    settings['SWIFT_VERSION'] = '5.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['SKIP_INSTALL'] = 'YES'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['DEVELOPMENT_TEAM'] = team if team
    # ต้องมาจาก Generated.xcconfig ที่ xcconfig ข้างบนดึงเข้ามา — เขียนเป็น
    # $(MARKETING_VERSION) ตรง ๆ จะอ้างถึงตัวเอง ได้ค่าว่าง แล้ว iOS ปฏิเสธการติดตั้ง
    settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = ''
    # extension ไม่ได้ลิงก์ Flutter/Pods เลย — มันวาด SwiftUI ล้วน ๆ จากข้อมูลที่ APNs
    # ส่งมาและจาก App Group การลาก Flutter.framework เข้ามาจะทำให้ App Store ตีกลับ
    # เรื่องขนาดและสิทธิ์
    settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  end

  # ฝัง extension ลงในแอปหลัก — ไม่มีขั้นนี้ก็บิลด์ผ่านแต่ไม่มีอะไรติดไปกับแอป
  embed_phase = runner.build_phases.find do |phase|
    phase.respond_to?(:name) && phase.name == 'Embed App Extensions'
  end
  embed_phase ||= begin
    phase = runner.new_copy_files_build_phase('Embed App Extensions')
    phase.symbol_dst_subfolder_spec = :plug_ins
    phase
  end
  build_file = embed_phase.add_file_reference(extension_target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

  # ต้องอยู่ "ก่อน" Thin Binary ของ Flutter ไม่งั้น Xcode มองเป็น dependency cycle
  # (Thin Binary ประกาศ Runner.app ทั้งก้อนเป็น output ส่วนขั้นนี้เขียนไฟล์ลงข้างใน)
  # แล้วบิลด์ล้มด้วยข้อความ "Cycle inside Runner" ที่ไม่ได้บอกว่าเพราะอะไร
  thin_index = runner.build_phases.find_index do |phase|
    phase.respond_to?(:name) && phase.name == 'Thin Binary'
  end
  if thin_index
    runner.build_phases.delete(embed_phase)
    runner.build_phases.insert(thin_index, embed_phase)
  end

  runner.add_dependency(extension_target)
  puts "สร้างเป้าหมาย #{TARGET_NAME} แล้ว (bundle id: #{base_bundle_id}.LiveActivity)"
end

# ไฟล์ต้นทาง — ตรวจทุกครั้ง ไม่ใช่แค่ตอนสร้างเป้าหมาย เพราะการเพิ่มวิดเจ็ตตัวใหม่
# คือการเพิ่มไฟล์เข้าเป้าหมายที่มีอยู่แล้ว
EXTENSION_SOURCES.each do |name|
  file = group.find_file_by_path(name) || group.new_file(name)

  unless member?(extension_target, name)
    extension_target.add_file_references([file])
    puts "เพิ่ม #{name} เข้าเป้าหมาย #{TARGET_NAME} แล้ว"
  end

  next unless SHARED_SOURCES.include?(name)
  next if member?(runner, name)

  runner.add_file_references([file])
  puts "เพิ่ม #{name} เข้าเป้าหมาย Runner แล้ว (โครงสร้างต้องเป็นตัวเดียวกันทั้งสองฝั่ง)"
end

# App Group — ทางเดียวที่วิดเจ็ตอ่าน snapshot ที่แอปเขียนไว้ได้
entitlements = group.find_file_by_path(ENTITLEMENTS_NAME) || group.new_file(ENTITLEMENTS_NAME)
entitlements_path = "#{GROUP_NAME}/#{ENTITLEMENTS_NAME}"
extension_target.build_configurations.each do |config|
  next if config.build_settings['CODE_SIGN_ENTITLEMENTS'] == entitlements_path

  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
  puts "ตั้ง CODE_SIGN_ENTITLEMENTS ของ #{config.name} เป็น #{entitlements_path}"
end

project.save
puts 'เรียบร้อย'
